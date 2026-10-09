pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var allProviders: []
    property var enabledProviders: []
    property var states: ({})
    property var sources: ({})
    property var sourceFallbackNotes: ({})
    property int refreshIntervalMs: 300000
    property int revision: 0
    property bool popupOpen: false
    property double lastRefreshStarted: 0

    property var _registryDocument: ({ version: 1, providers: [] })
    property bool _registryLoaded: false
    property bool _settingsLoaded: false
    property bool _cacheLoaded: false
    property bool _initialStarted: false
    property bool _refreshAfterRegistryLoad: false
    property int _activeFetches: 0
    property bool _cacheDirty: false

    readonly property var _displayNames: ({
        codex: "Codex", claude: "Claude", gemini: "Gemini", openai: "OpenAI",
        copilot: "Copilot", cursor: "Cursor", kimi: "Kimi", zai: "z.ai",
        minimax: "MiniMax", ollama: "Ollama", vertexai: "Vertex AI",
        azureopenai: "Azure OpenAI", jetbrains: "JetBrains AI", factory: "Droid",
        antigravity: "Antigravity", opencode: "OpenCode", opencodego: "OpenCode Go",
        moonshot: "Moonshot / Kimi API", kimik2: "Kimi K2", t3chat: "T3 Chat",
        alibabatokenplan: "Alibaba Token Plan", wayfinder: "Wayfinder",
        amp: "Amp", augment: "Augment", devin: "Devin", kiro: "Kiro", kilo: "Kilo",
        manus: "Manus", synthetic: "Synthetic", alibaba: "Alibaba"
    })

    property Component _commandJobComponent: Component {
        QtObject {
            id: job

            property var commandLine: []
            property int timeoutMs: 0
            property var callback: null
            property string output: ""
            property string errorOutput: ""
            property bool started: false
            property bool timedOut: false
            property int exitCode: -1

            property var process: Process {
                command: job.commandLine
                stdout: StdioCollector {
                    onStreamFinished: job.output = text
                }
                stderr: StdioCollector {
                    onStreamFinished: job.errorOutput = text
                }
                onExited: (exitCode, exitStatus) => job.exitCode = exitCode
                onRunningChanged: {
                    if (!running && job.started) {
                        job.timeout.stop()
                        job.finishDelay.restart()
                    }
                }
            }

            property var timeout: Timer {
                interval: Math.max(1, job.timeoutMs)
                repeat: false
                onTriggered: {
                    if (job.process.running) {
                        job.timedOut = true
                        job.process.running = false
                    }
                }
            }

            property var finishDelay: Timer {
                interval: 0
                repeat: false
                onTriggered: {
                    job.started = false
                    if (job.callback)
                        job.callback(job.output, job.exitCode, job.timedOut, job.errorOutput)
                    job.destroy()
                }
            }

            function begin() {
                started = true
                if (timeoutMs > 0)
                    timeout.start()
                process.running = true
            }
        }
    }

    property var _refreshTimer: Timer {
        interval: root.refreshIntervalMs
        repeat: true
        running: true
        onIntervalChanged: restart()
        onTriggered: root.refreshAll()
    }

    property var _ipc: IpcHandler {
        target: "codexbar"

        function status(): string {
            return root.statusJson()
        }

        function toggle(): void {
            root.togglePopup()
        }

        function refresh(): void {
            root.refreshAll()
        }
    }

    Component.onCompleted: {
        _loadRegistry()
        _loadSettings()
        _loadCache()
    }

    function _runCommand(commandLine, timeoutMs, callback) {
        var job = _commandJobComponent.createObject(root, {
            commandLine: commandLine,
            timeoutMs: timeoutMs || 0,
            callback: callback
        })
        if (job)
            job.begin()
    }

    function _bump() {
        revision++
    }

    function _number(value, fallback) {
        return typeof value === "number" && isFinite(value) ? value : fallback
    }

    function _clampPercent(value) {
        return Math.round(Math.max(0, Math.min(100, _number(value, 0))))
    }

    function _object(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value)
    }

    function _base64Utf8(value) {
        return Qt.btoa(unescape(encodeURIComponent(value)))
    }

    function _atomicWrite(path, value, directory, backupPath, callback) {
        var encoded = _base64Utf8(value)
        var relativePath = path.indexOf("$HOME/") === 0 ? path.slice(6) : path
        var relativeDirectory = directory && directory.indexOf("$HOME/") === 0
                ? directory.slice(6) : directory
        var relativeBackup = backupPath && backupPath.indexOf("$HOME/") === 0
                ? backupPath.slice(6) : backupPath
        var command
        if (backupPath) {
            command = ["bash", "-c",
                       "target=\"$HOME/$2\"; backup=\"$HOME/$3\"; cp -n \"$target\" \"$backup\" 2>/dev/null || true; printf '%s' \"$1\" | base64 -d > \"$target.tmp\" && mv \"$target.tmp\" \"$target\"",
                       "_", encoded, relativePath, relativeBackup]
        } else if (directory) {
            command = ["bash", "-c",
                       "target=\"$HOME/$2\"; directory=\"$HOME/$3\"; mkdir -p \"$directory\" && printf '%s' \"$1\" | base64 -d > \"$target.tmp\" && mv \"$target.tmp\" \"$target\"",
                       "_", encoded, relativePath, relativeDirectory]
        } else {
            command = ["bash", "-c",
                       "target=\"$HOME/$2\"; printf '%s' \"$1\" | base64 -d > \"$target.tmp\" && mv \"$target.tmp\" \"$target\"",
                       "_", encoded, relativePath]
        }
        _runCommand(command, 10000, function(output, exitCode, timedOut, errorOutput) {
            if (callback)
                callback(!timedOut && exitCode === 0, errorOutput)
        })
    }

    function displayName(id) {
        if (typeof id !== "string" || id.length === 0)
            return "Unknown"
        if (_displayNames[id] !== undefined)
            return _displayNames[id]
        return id.charAt(0).toUpperCase() + id.slice(1)
    }

    function hasApi(id) {
        return id === "codex" || id === "claude"
    }

    function sourceFor(id) {
        var value = sources[id]
        return value === "cli" || value === "api" ? value : "auto"
    }

    function sourceNoteFor(id) {
        return sourceFallbackNotes[id] || ""
    }

    function stateFor(id) {
        return states[id] || null
    }

    function sortedProviders() {
        var result = allProviders.slice(0)
        result.sort(function(a, b) {
            var ae = a && a.enabled === true ? 0 : 1
            var be = b && b.enabled === true ? 0 : 1
            if (ae !== be)
                return ae - be
            return displayName(a && a.id || "").localeCompare(displayName(b && b.id || ""))
        })
        return result
    }

    function anyFetching() {
        var ids = Object.keys(states)
        for (var i = 0; i < ids.length; ++i) {
            if (states[ids[i]] && states[ids[i]].fetching)
                return true
        }
        return false
    }

    function _ensureState(id) {
        if (!states[id]) {
            states[id] = {
                id: id,
                data: null,
                raw: null,
                error: null,
                stale: false,
                lastSuccess: 0,
                cliFailedAt: 0,
                fetching: false
            }
        }
        return states[id]
    }

    function _loadRegistry() {
        _runCommand(["codexbar", "config", "dump"], 10000,
                    function(output, exitCode, timedOut, errorOutput) {
            if (!timedOut && _parseRegistry(output))
                return
            _runCommand(["bash", "-c",
                         "cat \"$HOME/.config/codexbar/config.json\" 2>/dev/null || cat \"$HOME/.codexbar/config.json\" 2>/dev/null || printf '{}'"],
                        5000, function(fallbackOutput) {
                if (!_parseRegistry(fallbackOutput))
                    _acceptRegistry({ version: 1, providers: [] })
            })
        })
    }

    function _parseRegistry(text) {
        var parsed
        try {
            parsed = JSON.parse((text || "").trim())
        } catch (error) {
            return false
        }
        if (!_object(parsed) || !Array.isArray(parsed.providers))
            return false
        _acceptRegistry(parsed)
        return true
    }

    function _acceptRegistry(document) {
        _registryDocument = document
        allProviders = document.providers.slice(0)
        var enabled = []
        for (var i = 0; i < allProviders.length; ++i) {
            var provider = allProviders[i]
            if (!_object(provider) || typeof provider.id !== "string")
                continue
            _ensureState(provider.id)
            if (provider.enabled === true)
                enabled.push(provider.id)
        }
        enabledProviders = enabled
        _registryLoaded = true
        _bump()
        _maybeInitialRefresh()
        if (_refreshAfterRegistryLoad) {
            _refreshAfterRegistryLoad = false
            refreshAll()
        }
    }

    function _loadSettings() {
        _runCommand(["bash", "-c",
                     "cat \"$HOME/.config/quickshell/codexbar-settings.json\" 2>/dev/null || printf '{}'"],
                    5000, function(output) {
            var parsed = {}
            try {
                parsed = JSON.parse((output || "{}").trim() || "{}")
            } catch (error) {
                parsed = {}
            }
            var loadedSources = {}
            if (_object(parsed) && _object(parsed.sources)) {
                var keys = Object.keys(parsed.sources)
                for (var i = 0; i < keys.length; ++i) {
                    var source = parsed.sources[keys[i]]
                    if (source === "auto" || source === "cli" || source === "api")
                        loadedSources[keys[i]] = source
                }
            }
            sources = loadedSources
            var interval = _object(parsed) ? _number(parsed.refreshIntervalMs, 300000) : 300000
            refreshIntervalMs = Math.max(30000, Math.round(interval))
            _settingsLoaded = true
            _bump()
            _maybeInitialRefresh()
        })
    }

    function _loadCache() {
        _runCommand(["bash", "-c",
                     "cat \"$HOME/.cache/quickshell-codexbar/state.json\" 2>/dev/null || printf '{}'"],
                    5000, function(output) {
            var parsed = {}
            try {
                parsed = JSON.parse((output || "{}").trim() || "{}")
            } catch (error) {
                parsed = {}
            }
            if (_object(parsed) && _object(parsed.providers)) {
                var ids = Object.keys(parsed.providers)
                for (var i = 0; i < ids.length; ++i) {
                    var cached = parsed.providers[ids[i]]
                    if (!_object(cached) || !_object(cached.data))
                        continue
                    var state = _ensureState(ids[i])
                    state.data = cached.data
                    state.lastSuccess = Math.max(0, _number(cached.lastSuccess, 0))
                    state.stale = true
                }
            }
            _cacheLoaded = true
            _bump()
            _maybeInitialRefresh()
        })
    }

    function _maybeInitialRefresh() {
        if (_initialStarted || !_registryLoaded || !_settingsLoaded || !_cacheLoaded)
            return
        _initialStarted = true
        refreshAll()
    }

    function setSource(id, source) {
        if (source !== "auto" && source !== "cli" && source !== "api")
            return
        var next = {}
        var keys = Object.keys(sources)
        for (var i = 0; i < keys.length; ++i)
            next[keys[i]] = sources[keys[i]]
        next[id] = source
        sources = next
        var settings = { sources: next, refreshIntervalMs: refreshIntervalMs }
        _atomicWrite("$HOME/.config/quickshell/codexbar-settings.json",
                     JSON.stringify(settings), "", "", function(ok, errorOutput) {
            if (!ok)
                console.warn("[CodexBar] Could not save settings:", errorOutput)
        })
        _bump()
        refreshProvider(id)
    }

    function setProviderEnabled(id, enabled) {
        if (!_object(_registryDocument) || !Array.isArray(_registryDocument.providers))
            return
        var found = false
        for (var i = 0; i < _registryDocument.providers.length; ++i) {
            var provider = _registryDocument.providers[i]
            if (_object(provider) && provider.id === id) {
                provider.enabled = enabled === true
                found = true
                break
            }
        }
        if (!found)
            return
        _atomicWrite("$HOME/.config/codexbar/config.json", JSON.stringify(_registryDocument),
                     "", "", function(ok, errorOutput) {
            if (!ok) {
                console.warn("[CodexBar] Could not save provider config:", errorOutput)
                return
            }
            root._registryLoaded = false
            root._refreshAfterRegistryLoad = true
            root._loadRegistry()
        })
    }

    function togglePopup() {
        popupOpen = !popupOpen
        if (popupOpen && Date.now() - lastRefreshStarted > 30000)
            refreshAll()
    }

    function refreshAll() {
        if (!_initialStarted)
            return
        lastRefreshStarted = Date.now()
        var ids = enabledProviders.slice(0)
        for (var i = 0; i < ids.length; ++i)
            refreshProvider(ids[i])
    }

    function refreshProvider(id) {
        if (!id)
            return
        var state = _ensureState(id)
        if (state.fetching)
            return
        state.fetching = true
        state.error = null
        _activeFetches++
        _bump()

        var preference = sourceFor(id)
        var notes = {}
        var noteKeys = Object.keys(sourceFallbackNotes)
        for (var n = 0; n < noteKeys.length; ++n)
            notes[noteKeys[n]] = sourceFallbackNotes[noteKeys[n]]
        delete notes[id]
        sourceFallbackNotes = notes

        if (preference === "api") {
            if (hasApi(id)) {
                _fetchApi(id)
            } else {
                notes[id] = "API is unavailable for this provider; using CLI."
                sourceFallbackNotes = notes
                _runCli(id, "", "direct")
                _bump()
            }
            return
        }

        if (preference === "auto" && hasApi(id)
                && state.cliFailedAt > 0
                && Date.now() - state.cliFailedAt < 30 * 60 * 1000) {
            _fetchApi(id)
            return
        }

        var override = id === "codex" || id === "claude" ? "oauth" : ""
        _runCli(id, override, override === "oauth" ? "oauth" : "direct")
    }

    function _runCli(id, override, stage) {
        var command = ["codexbar", "usage", "--provider", id,
                       "--format", "json", "--no-color"]
        if (override)
            command.push("--source", override)
        _runCommand(command, 30000, function(output, exitCode, timedOut, errorOutput) {
            if (timedOut) {
                root._handleCliFailure(id, "CLI request timed out", false, stage)
                return
            }
            var parsed = root._parseCliPayload(output)
            if (parsed.ok) {
                root._applySuccess(id, parsed.data, parsed.raw)
                return
            }
            var message = parsed.message || (errorOutput || "CLI returned malformed data").trim()
            root._handleCliFailure(id, message, parsed.permanent === true, stage)
        })
    }

    function _parseCliPayload(text) {
        var payload
        try {
            payload = JSON.parse((text || "").trim())
        } catch (error) {
            return { ok: false, message: "CLI returned malformed JSON", permanent: false }
        }
        if (!Array.isArray(payload) || payload.length === 0 || !_object(payload[0]))
            return { ok: false, message: "CLI returned malformed data", permanent: false }
        var entry = payload[0]
        if (_object(entry.error)) {
            var errorMessage = typeof entry.error.message === "string"
                    ? entry.error.message : "Provider error"
            return { ok: false, message: errorMessage,
                     permanent: /(^|\D)[45][0-9][0-9](\D|$)/.test(errorMessage) }
        }
        if (!_object(entry.usage))
            return { ok: false, message: "CLI response has no usage data", permanent: false }
        var normalized = _normalizeCli(entry)
        if (!normalized)
            return { ok: false, message: "CLI response shape was not recognized", permanent: false }
        return { ok: true, data: normalized, raw: entry }
    }

    function _normalizeCli(entry) {
        if (!_object(entry) || !_object(entry.usage))
            return null
        var usage = entry.usage
        var pace = _object(entry.pace) ? entry.pace : {}
        var windows = []
        var keys = ["primary", "secondary", "tertiary"]
        for (var i = 0; i < keys.length; ++i) {
            var key = keys[i]
            if (!_object(usage[key]))
                continue
            windows.push(_normalizeCliWindow(key, usage[key], pace[key], null))
        }
        if (Array.isArray(usage.extraRateWindows)) {
            for (var j = 0; j < usage.extraRateWindows.length; ++j) {
                var extra = usage.extraRateWindows[j]
                if (!_object(extra) || !_object(extra.window))
                    continue
                var extraKey = typeof extra.id === "string" ? extra.id : "extra-" + j
                var title = typeof extra.title === "string" ? extra.title : null
                windows.push(_normalizeCliWindow(extraKey, extra.window, pace[extraKey], title))
            }
        }
        var plan = null
        if (typeof usage.loginMethod === "string")
            plan = usage.loginMethod
        else if (_object(usage.identity) && typeof usage.identity.loginMethod === "string")
            plan = usage.identity.loginMethod
        var cost = null
        if (_object(usage.providerCost)) {
            var rawCost = usage.providerCost
            var used = _number(rawCost.used, NaN)
            var limit = _number(rawCost.limit, NaN)
            if (isFinite(used) && isFinite(limit)) {
                cost = {
                    used: Math.max(0, used),
                    limit: Math.max(0, limit),
                    currencyCode: typeof rawCost.currencyCode === "string" ? rawCost.currencyCode : "USD",
                    period: typeof rawCost.period === "string" ? rawCost.period : "Limit"
                }
            }
        }
        return {
            windows: windows,
            planLabel: plan,
            cost: cost,
            updatedAt: typeof usage.updatedAt === "string" ? usage.updatedAt : new Date().toISOString(),
            source: "cli"
        }
    }

    function _normalizeCliWindow(key, value, pace, explicitLabel) {
        var minutes = _number(value.windowMinutes, null)
        if (minutes !== null)
            minutes = Math.max(0, Math.round(minutes))
        return {
            key: key,
            label: explicitLabel || windowLabel(minutes, key),
            usedPercent: _clampPercent(value.usedPercent),
            resetsAt: typeof value.resetsAt === "string" ? value.resetsAt : null,
            resetDescription: typeof value.resetDescription === "string" ? value.resetDescription : null,
            windowMinutes: minutes,
            paceSummary: _object(pace) && typeof pace.summary === "string" ? pace.summary : null
        }
    }

    function windowLabel(minutes, key) {
        if (typeof minutes !== "number" || !isFinite(minutes)) {
            if (key === "primary") return "Session"
            if (key === "secondary") return "Weekly"
            if (key === "tertiary") return "Extra"
            return "Extra"
        }
        var known = [
            { minutes: 300, label: "5h" },
            { minutes: 1440, label: "Day" },
            { minutes: 10080, label: "Week" },
            { minutes: 43200, label: "Month" },
            { minutes: 525600, label: "Year" }
        ]
        for (var i = 0; i < known.length; ++i) {
            if (Math.abs(minutes - known[i].minutes) <= known[i].minutes * 0.05)
                return known[i].label
        }
        if (minutes < 48 * 60)
            return Math.max(1, Math.round(minutes / 60)) + "h"
        return Math.max(1, Math.round(minutes / 1440)) + "d"
    }

    function _handleCliFailure(id, message, permanent, stage) {
        var state = _ensureState(id)
        var preference = sourceFor(id)
        if (id === "claude" && stage === "oauth") {
            _runCli(id, "cli", "claude-cli")
            return
        }
        if (preference === "auto") {
            state.cliFailedAt = Date.now()
            _bump()
            if (hasApi(id)) {
                _fetchApi(id)
                return
            }
        }
        _applyFailure(id, message, permanent)
    }

    function _fetchApi(id) {
        if (id === "codex")
            _fetchCodexApi()
        else if (id === "claude")
            _fetchClaudeApi()
        else
            _applyFailure(id, "No API path for " + displayName(id), true)
    }

    function _decodeJwt(token) {
        if (typeof token !== "string")
            return null
        var parts = token.split(".")
        if (parts.length < 2)
            return null
        var encoded = parts[1].replace(/-/g, "+").replace(/_/g, "/")
        while (encoded.length % 4 !== 0)
            encoded += "="
        try {
            var binary = Qt.atob(encoded)
            var escaped = ""
            for (var i = 0; i < binary.length; ++i) {
                var hex = binary.charCodeAt(i).toString(16)
                escaped += "%" + (hex.length < 2 ? "0" : "") + hex
            }
            return JSON.parse(decodeURIComponent(escaped))
        } catch (error) {
            return null
        }
    }

    function _fetchCodexApi() {
        _runCommand(["bash", "-c", "cat \"$HOME/.codex/auth.json\" 2>/dev/null || printf '{}'"],
                    5000, function(output, exitCode, timedOut) {
            if (timedOut) {
                root._applyFailure("codex", "Could not read Codex credentials", false)
                return
            }
            var auth
            try {
                auth = JSON.parse((output || "{}").trim() || "{}")
            } catch (error) {
                root._applyFailure("codex", "Codex credentials are malformed", false)
                return
            }
            if (!root._object(auth) || !root._object(auth.tokens)) {
                root._applyFailure("codex", "Codex credentials are unavailable", true)
                return
            }
            var accessPayload = root._decodeJwt(auth.tokens.access_token)
            var exp = root._object(accessPayload) ? root._number(accessPayload.exp, 0) : 0
            if (exp * 1000 > Date.now() + 5 * 60 * 1000)
                root._getCodexUsage(auth, false)
            else
                root._refreshCodexToken(auth)
        })
    }

    function _codexPlan(auth) {
        if (!_object(auth) || !_object(auth.tokens))
            return null
        var payload = _decodeJwt(auth.tokens.id_token)
        var claim = _object(payload) ? payload["https://api.openai.com/auth"] : null
        return _object(claim) && typeof claim.chatgpt_plan_type === "string"
                ? claim.chatgpt_plan_type : null
    }

    function _getCodexUsage(auth, refreshed) {
        var tokens = auth.tokens
        if (typeof tokens.access_token !== "string" || typeof tokens.account_id !== "string") {
            _applyFailure("codex", "Codex OAuth tokens are incomplete", true)
            return
        }
        _request("GET", "https://chatgpt.com/backend-api/wham/usage", {
            Authorization: "Bearer " + tokens.access_token,
            "chatgpt-account-id": tokens.account_id
        }, null, function(result) {
            if (result.status === 401 && !refreshed) {
                root._refreshCodexToken(auth)
                return
            }
            if (!result.ok) {
                root._applyHttpFailure("codex", result)
                return
            }
            var payload
            try {
                payload = JSON.parse(result.text)
            } catch (error) {
                root._applyFailure("codex", "Codex API returned malformed JSON", false)
                return
            }
            var normalized = root._normalizeCodexApi(payload, root._codexPlan(auth))
            if (!normalized) {
                root._applyFailure("codex", "Codex API response shape was not recognized", false)
                return
            }
            root._applySuccess("codex", normalized, payload)
        })
    }

    function _refreshCodexToken(auth) {
        var refreshToken = _object(auth.tokens) ? auth.tokens.refresh_token : null
        if (typeof refreshToken !== "string" || refreshToken.length === 0) {
            _applyFailure("codex", "Codex refresh token is unavailable", true)
            return
        }
        var body = JSON.stringify({
            client_id: "app_EMoamEEZ73f0CkXaXp7hrann",
            grant_type: "refresh_token",
            refresh_token: refreshToken,
            scope: "openid profile email"
        })
        _request("POST", "https://auth.openai.com/oauth/token",
                 { "Content-Type": "application/json" }, body, function(result) {
            if (!result.ok) {
                root._applyHttpFailure("codex", result)
                return
            }
            var fresh
            try {
                fresh = JSON.parse(result.text)
            } catch (error) {
                root._applyFailure("codex", "OAuth refresh returned malformed JSON", false)
                return
            }
            if (!root._object(fresh) || typeof fresh.access_token !== "string") {
                root._applyFailure("codex", "OAuth refresh response was incomplete", false)
                return
            }
            auth.tokens.access_token = fresh.access_token
            if (typeof fresh.refresh_token === "string") auth.tokens.refresh_token = fresh.refresh_token
            if (typeof fresh.id_token === "string") auth.tokens.id_token = fresh.id_token
            auth.last_refresh = new Date().toISOString()
            root._atomicWrite("$HOME/.codex/auth.json", JSON.stringify(auth), "",
                              "$HOME/.codex/auth.json.qs-backup", function(ok, errorOutput) {
                if (!ok) {
                    root._applyFailure("codex", "Could not save refreshed OAuth tokens", false)
                    return
                }
                root._getCodexUsage(auth, true)
            })
        })
    }

    function _normalizeCodexApi(payload, plan) {
        if (!_object(payload) || !_object(payload.rate_limit))
            return null
        var windows = []
        var pairs = [
            { key: "primary", value: payload.rate_limit.primary_window },
            { key: "secondary", value: payload.rate_limit.secondary_window }
        ]
        for (var i = 0; i < pairs.length; ++i) {
            var value = pairs[i].value
            if (!_object(value))
                continue
            var seconds = _number(value.limit_window_seconds, null)
            if (seconds === null || seconds <= 0)
                return null
            var resetIso = _resetIso(value.reset_at)
            var used = _clampPercent(value.used_percent)
            windows.push({
                key: pairs[i].key,
                label: windowLabel(seconds / 60, pairs[i].key),
                usedPercent: used,
                resetsAt: resetIso,
                resetDescription: null,
                windowMinutes: Math.round(seconds / 60),
                paceSummary: _paceSummary(used, resetIso, seconds)
            })
        }
        if (windows.length === 0)
            return null
        return {
            windows: windows,
            planLabel: plan,
            cost: null,
            updatedAt: new Date().toISOString(),
            source: "api"
        }
    }

    function _resetIso(value) {
        if (typeof value === "number" && isFinite(value))
            return new Date(value * 1000).toISOString()
        if (typeof value === "string" && !isNaN(Date.parse(value)))
            return new Date(value).toISOString()
        return null
    }

    function _paceSummary(used, resetIso, windowSeconds) {
        if (!resetIso || typeof windowSeconds !== "number" || windowSeconds <= 0)
            return null
        var resetMs = Date.parse(resetIso)
        if (!isFinite(resetMs))
            return null
        var elapsed = windowSeconds - (resetMs / 1000 - Date.now() / 1000)
        var expected = Math.round(Math.max(0, Math.min(100, 100 * elapsed / windowSeconds)))
        var delta = expected - used
        return delta >= 0
                ? delta + "% in reserve | Expected " + expected + "% used"
                : -delta + "% over pace | Expected " + expected + "% used"
    }

    function _fetchClaudeApi() {
        _runCommand(["bash", "-c", "cat \"$HOME/.claude/.credentials.json\" 2>/dev/null || printf '{}'"],
                    5000, function(output, exitCode, timedOut) {
            if (timedOut) {
                root._applyFailure("claude", "Could not read Claude credentials", false)
                return
            }
            var credentials
            try {
                credentials = JSON.parse((output || "{}").trim() || "{}")
            } catch (error) {
                root._applyFailure("claude", "Claude credentials are malformed", false)
                return
            }
            var oauth = root._object(credentials) ? credentials.claudeAiOauth : null
            if (!root._object(oauth) || typeof oauth.accessToken !== "string") {
                root._applyFailure("claude", "Claude OAuth credentials are unavailable", true)
                return
            }
            if (root._number(oauth.expiresAt, 0) <= Date.now()) {
                root._applyFailure("claude", "Claude OAuth credentials have expired", false)
                return
            }
            root._request("GET", "https://api.anthropic.com/api/oauth/usage", {
                Authorization: "Bearer " + oauth.accessToken,
                "anthropic-beta": "oauth-2025-04-20",
                "Content-Type": "application/json"
            }, null, function(result) {
                if (!result.ok) {
                    root._applyHttpFailure("claude", result)
                    return
                }
                var payload
                try {
                    payload = JSON.parse(result.text)
                } catch (error) {
                    root._applyFailure("claude", "Claude API returned malformed JSON", false)
                    return
                }
                var plan = typeof oauth.subscriptionType === "string" ? oauth.subscriptionType : null
                var normalized = root._normalizeClaudeApi(payload, plan)
                if (!normalized) {
                    root._applyFailure("claude", "Claude API response shape was not recognized", false)
                    return
                }
                root._applySuccess("claude", normalized, payload)
            })
        })
    }

    function _normalizeClaudeApi(payload, plan) {
        var candidates = []
        if (Array.isArray(payload)) {
            candidates = payload
        } else if (_object(payload)) {
            var keys = ["five_hour", "seven_day"]
            for (var i = 0; i < keys.length; ++i) {
                if (_object(payload[keys[i]]))
                    candidates.push({ id: keys[i], value: payload[keys[i]] })
            }
        } else {
            return null
        }
        var windows = []
        for (var j = 0; j < candidates.length; ++j) {
            var candidate = candidates[j]
            var id = candidate.id || candidate.key || candidate.name
            var value = _object(candidate.value) ? candidate.value : candidate
            if (id !== "five_hour" && id !== "seven_day")
                continue
            if (typeof value.utilization !== "number" || !isFinite(value.utilization))
                return null
            var minutes = id === "five_hour" ? 300 : 10080
            windows.push({
                key: id,
                label: id === "five_hour" ? "5h" : "Week",
                usedPercent: _clampPercent(value.utilization),
                resetsAt: _resetIso(value.resets_at),
                resetDescription: null,
                windowMinutes: minutes,
                paceSummary: null
            })
        }
        if (windows.length === 0)
            return null
        return {
            windows: windows,
            planLabel: plan,
            cost: null,
            updatedAt: new Date().toISOString(),
            source: "api"
        }
    }

    function _request(method, url, headers, body, callback) {
        var xhr = new XMLHttpRequest()
        var finished = false
        function finish(result) {
            if (finished)
                return
            finished = true
            callback(result)
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            var status = Number(xhr.status) || 0
            finish({
                ok: status >= 200 && status < 300,
                status: status,
                statusText: xhr.statusText || "",
                text: xhr.responseText || "",
                transient: status === 0
            })
        }
        xhr.ontimeout = function() {
            finish({ ok: false, status: 0, statusText: "timeout", text: "", transient: true })
        }
        xhr.onerror = function() {
            finish({ ok: false, status: 0, statusText: "network error", text: "", transient: true })
        }
        try {
            xhr.open(method, url)
            xhr.timeout = 30000
            var names = Object.keys(headers || {})
            for (var i = 0; i < names.length; ++i)
                xhr.setRequestHeader(names[i], headers[names[i]])
            xhr.send(body)
        } catch (error) {
            finish({ ok: false, status: 0, statusText: error.toString(), text: "", transient: true })
        }
    }

    function _applyHttpFailure(id, result) {
        if (result.status === 0 || result.transient) {
            _applyFailure(id, result.statusText || "Network unavailable", false)
            return
        }
        var detail = result.statusText ? " " + result.statusText : ""
        _applyFailure(id, "HTTP " + result.status + detail, true)
    }

    function _applySuccess(id, data, raw) {
        var state = _ensureState(id)
        state.data = data
        state.raw = raw
        state.error = null
        state.stale = false
        state.lastSuccess = Date.now()
        state.cliFailedAt = data.source === "cli" ? 0 : state.cliFailedAt
        _cacheDirty = true
        _finishProvider(id)
    }

    function _applyFailure(id, message, permanent) {
        var state = _ensureState(id)
        state.stale = true
        state.error = permanent ? { message: message, permanent: true } : null
        _finishProvider(id)
    }

    function _finishProvider(id) {
        var state = _ensureState(id)
        state.fetching = false
        _activeFetches = Math.max(0, _activeFetches - 1)
        _bump()
        if (_activeFetches === 0 && _cacheDirty) {
            _cacheDirty = false
            _writeCache()
        }
    }

    function _writeCache() {
        var providers = {}
        var ids = Object.keys(states)
        for (var i = 0; i < ids.length; ++i) {
            var state = states[ids[i]]
            if (state && state.data)
                providers[ids[i]] = { data: state.data, lastSuccess: state.lastSuccess }
        }
        var document = { providers: providers, savedAt: Date.now() }
        _atomicWrite("$HOME/.cache/quickshell-codexbar/state.json",
                     JSON.stringify(document), "$HOME/.cache/quickshell-codexbar", "",
                     function(ok, errorOutput) {
            if (!ok)
                console.warn("[CodexBar] Could not write cache:", errorOutput)
        })
    }

    function _formatReset(value) {
        if (typeof value !== "string" || isNaN(Date.parse(value)))
            return "unknown"
        return Qt.formatDateTime(new Date(value), "MMM d, h:mm AP")
    }

    function _money(value) {
        var number = _number(value, 0)
        return Math.round(number * 100) / 100
    }

    function statusJson() {
        var pct = 0
        var anyStale = false
        var lines = []
        var allErrored = enabledProviders.length > 0
        for (var i = 0; i < enabledProviders.length; ++i) {
            var id = enabledProviders[i]
            var name = displayName(id)
            var state = states[id]
            if (!state || state.data || !state.error)
                allErrored = false
            if (state && state.stale)
                anyStale = true
            if (state && state.data && Array.isArray(state.data.windows)) {
                for (var j = 0; j < state.data.windows.length; ++j) {
                    var window = state.data.windows[j]
                    var used = _clampPercent(window.usedPercent)
                    pct = Math.max(pct, used)
                    var reset = typeof window.resetDescription === "string"
                            ? window.resetDescription : _formatReset(window.resetsAt)
                    lines.push(name + " " + window.label + ": " + used + "% — resets " + reset)
                    if (typeof window.paceSummary === "string" && window.paceSummary.length > 0)
                        lines.push(name + " " + window.label + " pace: " + window.paceSummary)
                }
                if (_object(state.data.cost)) {
                    var cost = state.data.cost
                    lines.push(name + " " + cost.period + ": $" + _money(cost.used)
                               + " / $" + _money(cost.limit))
                }
            }
            if (state && state.error)
                lines.push(name + ": error — " + state.error.message)
            var note = sourceNoteFor(id)
            if (note)
                lines.push(name + ": " + note)
        }
        var cssClass
        if (allErrored)
            cssClass = "stale"
        else if (pct >= 90)
            cssClass = "critical"
        else if (pct >= 70)
            cssClass = "warning"
        else if (anyStale)
            cssClass = "stale"
        else
            cssClass = "ok"
        return JSON.stringify({
            text: allErrored ? "🤖 ⚠" : "🤖 " + pct + "%",
            tooltip: lines.join("\n"),
            class: cssClass,
            percentage: Math.round(pct)
        })
    }
}

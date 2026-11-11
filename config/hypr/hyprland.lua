-- ─────────────────────────────────────────────
-- Hyprland — Fido (Lua, Hyprland 0.57+)
-- hyprland.conf'tan çevrildi 2026-11-11. Eski dosya referans olarak duruyor, artık okunmuyor.
-- Wiki: https://wiki.hypr.land/configuring/   API: /usr/share/hypr/stubs/hl.meta.lua
-- Renkler matugen tarafından üretilir → colors.lua (elle düzenleme)
-- ─────────────────────────────────────────────

local colors = require("./colors.lua")

-- Nvidia-specific env variables
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


------------------
---- MONITORS ----
------------------

-- HDMI-A-1 = ANA EKRAN (solda, 0x0), eDP-1 = laptop paneli (sağda, 1920x0)
hl.monitor({ output = "eDP-1",    mode = "1920x1080@144", position = "1920x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144", position = "0x0",    scale = 1 })


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "kitty -e yazi"
local menu        = "rofi -show drun"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal)
    hl.exec_cmd("waybar & awww-daemon & quickshell & swayosd-server")

    -- Pano geçmişi — cliphist. Geçmiş RAM'de tutulur (~/.config/cliphist/config →
    -- db-path /run/user/1000/cliphist/db), reboot'ta silinir. Şifre yöneticisi
    -- kaynaklı girdiler cliphist-store.sh içinde elenir.
    hl.exec_cmd("wl-paste --type text  --watch ~/.local/bin/cliphist-store.sh")
    hl.exec_cmd("wl-paste --type image --watch ~/.local/bin/cliphist-store.sh")

    -- Kulaklık (G733) düşük pil izleyicisi — uyarı sıklığı pil düştükçe artar
    hl.exec_cmd("~/.local/bin/headset-battery-watch.sh")

    -- Video wallpaper otomatik duraklatma — masaüstü pencerelerle kapandığında mpv durur
    hl.exec_cmd("~/.local/bin/wallpaper-autopause.py")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border   = { colors = { colors.primary, colors.tertiary }, angle = 45 },
            inactive_border = colors.outlineVariant,
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = colors.shadow,
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        -- pseudotile = true -- SUPER+P ile bağlı
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },
})

-- Animasyonlar (eski config'teki değerler, hepsi bezier)
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "tr",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"
local function key(k) return mainMod .. " + " .. k end

hl.bind(key("Q"), hl.dsp.exec_cmd(terminal))
hl.bind(key("C"), hl.dsp.window.close())
hl.bind(key("M"), hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(key("E"), hl.dsp.exec_cmd(fileManager))

-- Wi-Fi / Bluetooth panelleri (quickshell)
hl.bind(key("N"),         hl.dsp.exec_cmd("qs ipc call wifi toggle"))
hl.bind(key("SHIFT + N"), hl.dsp.exec_cmd("qs ipc call bluetooth toggle"))

-- Kulaklık pili
hl.bind(key("B"),         hl.dsp.exec_cmd("~/.local/bin/headset-battery.sh --notify"))
hl.bind(key("SHIFT + B"), hl.dsp.exec_cmd("~/.local/bin/headset-battery.sh --speak"))

-- Pano geçmişi (cliphist + rofi)
hl.bind(key("V"),        hl.dsp.exec_cmd("~/.local/bin/clipboard-menu.sh"))
hl.bind(key("CTRL + V"), hl.dsp.window.float({ action = "toggle" }))
hl.bind(key("R"),        hl.dsp.exec_cmd(menu))
hl.bind(key("P"),        hl.dsp.window.pseudo())          -- dwindle
hl.bind(key("J"),        hl.dsp.layout("togglesplit"))    -- dwindle
hl.bind("Print",         hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind(key("TAB"),      hl.dsp.exec_cmd("rofi -show window"))
hl.bind(key("W"),        hl.dsp.exec_cmd("~/.local/bin/wallpaper-picker.sh"))
hl.bind(key("L"),        hl.dsp.exec_cmd("hyprlock"))
hl.bind(key("F"),        hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Odak: SUPER + ok tuşları
hl.bind(key("left"),  hl.dsp.focus({ direction = "left" }))
hl.bind(key("right"), hl.dsp.focus({ direction = "right" }))
hl.bind(key("up"),    hl.dsp.focus({ direction = "up" }))
hl.bind(key("down"),  hl.dsp.focus({ direction = "down" }))

-- Çalışma alanları: SUPER + [0-9] geç, SUPER + SHIFT + [0-9] pencereyi taşı
for i = 1, 10 do
    local k = i % 10 -- 10 → 0 tuşu
    hl.bind(key(k),             hl.dsp.focus({ workspace = i }))
    hl.bind(key("SHIFT + " .. k), hl.dsp.window.move({ workspace = i }))
end

hl.bind(key("S"),         hl.dsp.workspace.toggle_special("magic"))
hl.bind(key("SHIFT + S"), hl.dsp.window.move({ workspace = "special:magic" }))

-- SUPER + tekerlek ile çalışma alanları arasında gez
hl.bind(key("mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(key("mouse_up"),   hl.dsp.focus({ workspace = "e-1" }))

-- SUPER + sol/sağ tık sürükle: taşı / boyutlandır
hl.bind(key("mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- Ses ve parlaklık (bindel → locked + repeating)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Medya (bindl → locked), playerctl gerekir
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- STT (kronos): basılı tut konuş, bırakınca dur
hl.bind("XF86Calculator", hl.dsp.exec_cmd("~/Documents/Python/kronos/stt_start.sh"))
hl.bind("XF86Calculator", hl.dsp.exec_cmd("~/Documents/Python/kronos/stt_stop.sh"), { release = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name    = "kitty-opacity",
    match   = { class = "kitty" },
    opacity = "0.85 0.85",
})

hl.window_rule({
    -- Uygulamaların maximize isteklerini yok say
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- XWayland sürükleme sorunları için
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

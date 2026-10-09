-- ─────────────────────────────────────────────
-- Minimal Neovim Config with Matugen Integration
-- ~/.config/nvim/init.lua
-- ─────────────────────────────────────────────

-- ── Temel Ayarlar ──
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.termguicolors = true
vim.o.signcolumn = "yes"
vim.o.scrolloff = 8
vim.o.clipboard = "unnamedplus"
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.undofile = true

-- ── Matugen Colorscheme Yükle ──
local function load_matugen()
    local path = vim.fn.expand("~/.config/nvim/matugen-colors.lua")
    local f = io.open(path, "r")
    if f then
        f:close()
        dofile(path)
    else
        -- Matugen henüz çalışmadıysa varsayılan tema
        vim.cmd("colorscheme habamax")
    end
end

load_matugen()

-- ── Hot-Reload: matugen çalışınca otomatik güncelle ──
-- matugen post_hook'tan: pkill -SIGUSR1 nvim
vim.api.nvim_create_autocmd("Signal", {
    pattern = "SIGUSR1",
    callback = load_matugen,
})

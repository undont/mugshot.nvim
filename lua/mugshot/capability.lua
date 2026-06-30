-- decide whether the rich (avatar) card is available, or degrade to text.
-- the verdict is memoised; pass force=true to re-detect

local M = {}

---@class mugshot.Capability
---@field image boolean  image.nvim is installed
---@field terminal boolean  terminal speaks the kitty graphics protocol
---@field tmux_ok boolean  not in tmux, or allow-passthrough is on
---@field ok boolean  all of the above; render avatars
---@field reason string?  why the rich card is unavailable

local cached

local function has_image()
    return pcall(require, "image")
end

-- ghostty/kitty/wezterm speak the kitty graphics protocol. inside tmux,
-- TERM_PROGRAM reads "tmux", so sniff the per-terminal env vars that survive
-- the passthrough instead
function M._kitty_capable()
    if vim.env.MUGSHOT_FORCE_KITTY == "1" then
        return true
    end
    if vim.env.KITTY_WINDOW_ID then
        return true
    end
    if vim.env.GHOSTTY_RESOURCES_DIR or vim.env.GHOSTTY_BIN_DIR then
        return true
    end
    if vim.env.WEZTERM_PANE then
        return true
    end
    local prog = (vim.env.TERM_PROGRAM or ""):lower()
    local term = (vim.env.TERM or ""):lower()
    return prog:find("kitty") ~= nil or prog:find("ghostty") ~= nil or term:find("kitty") ~= nil
end

---@return boolean ok, string? reason
local function tmux_passthrough()
    if not vim.env.TMUX then
        return true
    end
    local res = vim.system({ "tmux", "show", "-gv", "allow-passthrough" }, { text = true }):wait()
    local val = vim.trim(res.stdout or "")
    if val == "on" or val == "all" then
        return true
    end
    return false,
        ("tmux allow-passthrough is '%s'; set it to 'on' for avatars"):format(
            val == "" and "off" or val
        )
end

-- compose the verdict from the three checks; pure so it can be unit-tested
---@param image boolean
---@param terminal boolean
---@param tmux_ok boolean
---@param tmux_reason string?
---@return mugshot.Capability
function M._verdict(image, terminal, tmux_ok, tmux_reason)
    local reason
    if not image then
        reason = "image.nvim not found; install 3rd/image.nvim for avatars"
    elseif not terminal then
        reason = "terminal does not speak the kitty graphics protocol"
    elseif not tmux_ok then
        reason = tmux_reason
    end
    return {
        image = image,
        terminal = terminal,
        tmux_ok = tmux_ok,
        ok = image and terminal and tmux_ok,
        reason = reason,
    }
end

---@param force? boolean
---@return mugshot.Capability
function M.detect(force)
    if cached and not force then
        return cached
    end
    local tmux_ok, tmux_reason = tmux_passthrough()
    cached = M._verdict(has_image(), M._kitty_capable(), tmux_ok, tmux_reason)
    return cached
end

return M

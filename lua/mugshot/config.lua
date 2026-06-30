-- default options and user-opt merge

local M = {}

---@class mugshot.AvatarConfig
---@field width integer  cell width of the avatar block in the card
---@field height integer  cell height of the avatar block in the card
---@field size integer  pixel size the cached png is pre-resized to
---@field shape "square"|"rounded"

---@class mugshot.CacheConfig
---@field dir string
---@field login_ttl integer  ttl for the email->login lookup, seconds

---@class mugshot.ActionsConfig
---@field open_commit string
---@field copy_sha string
---@field open_pr string
---@field dismiss string|string[]

---@class mugshot.Config
---@field keymap string|false  trigger that opens the card for the current line
---@field actions mugshot.ActionsConfig  buffer-local keys inside the focused card
---@field hint_row boolean  render the dim hint row at the foot of the card
---@field avatar mugshot.AvatarConfig
---@field cache mugshot.CacheConfig
---@field gravatar boolean  fall back to gravatar when github has no linked user
local defaults = {
    keymap = "gb",
    actions = {
        open_commit = "o",
        copy_sha = "y",
        open_pr = "p",
        dismiss = { "q", "<Esc>" },
    },
    hint_row = true,
    avatar = {
        width = 8,
        height = 4,
        size = 128,
        shape = "square",
    },
    cache = {
        dir = vim.fn.stdpath("cache") .. "/mugshot",
        login_ttl = 30 * 24 * 60 * 60,
    },
    gravatar = true,
}

M.defaults = defaults
M.options = vim.deepcopy(defaults)

---@param opts? mugshot.Config
---@return mugshot.Config
function M.setup(opts)
    opts = opts or {}
    M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
    -- deep-extend index-merges list values; replace the dismiss list wholesale so
    -- `dismiss = { "x" }` means exactly { "x" }, not { "x", "<Esc>" }
    if opts.actions and opts.actions.dismiss ~= nil then
        M.options.actions.dismiss = vim.deepcopy(opts.actions.dismiss)
    end
    return M.options
end

return M

-- public api: setup() + the blame-card trigger

local config = require("mugshot.config")

local M = {}

---@param opts? mugshot.Config
function M.setup(opts)
  local o = config.setup(opts)
  if o.keymap then
    vim.keymap.set("n", o.keymap, M.show, { desc = "mugshot: blame card for current line" })
  end
end

-- open the blame card for the line under the cursor
function M.show()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    return vim.notify("mugshot: buffer has no file", vim.log.levels.WARN)
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local cwd = vim.fs.dirname(file)
  require("mugshot.blame").blame_line(file, lnum, function(info, err)
    if not info then
      return vim.notify("mugshot: " .. (err or "blame failed"), vim.log.levels.ERROR)
    end
    require("mugshot.card").open(info, cwd)
  end)
end

return M

-- card actions: open commit, copy sha, open pr. all need a github origin

local util = require("mugshot.util")

local M = {}

local function no_remote()
  vim.notify("mugshot: no github origin remote", vim.log.levels.WARN)
end

local function not_committed()
  vim.notify("mugshot: line is not committed yet", vim.log.levels.WARN)
end

-- copy the full sha to the unnamed and system registers
---@param sha string
function M.copy_sha(sha)
  vim.fn.setreg('"', sha)
  pcall(vim.fn.setreg, "+", sha)
  vim.notify("mugshot: copied " .. sha:sub(1, 7))
end

-- open the commit page in the browser
---@param info mugshot.BlameInfo
---@param cwd string
function M.open_commit(info, cwd)
  if info.uncommitted then return not_committed() end
  util.repo_slug(cwd, function(slug)
    vim.schedule(function()
      if not slug then return no_remote() end
      vim.ui.open(("https://github.com/%s/commit/%s"):format(slug, info.sha))
    end)
  end)
end

-- open the PR that introduced the commit; falls back to the commit page
---@param info mugshot.BlameInfo
---@param cwd string
function M.open_pr(info, cwd)
  if info.uncommitted then return not_committed() end
  util.repo_slug(cwd, function(slug)
    if not slug then return vim.schedule(no_remote) end
    vim.system(
      { "gh", "api", ("repos/%s/commits/%s/pulls"):format(slug, info.sha), "--jq", ".[0].html_url // empty" },
      { cwd = cwd, text = true },
      function(res)
        vim.schedule(function()
          local url = vim.trim(res.stdout or "")
          if res.code == 0 and url ~= "" then
            vim.ui.open(url)
          else
            vim.notify("mugshot: no PR for " .. info.abbrev .. ", opening commit", vim.log.levels.INFO)
            vim.ui.open(("https://github.com/%s/commit/%s"):format(slug, info.sha))
          end
        end)
      end
    )
  end)
end

return M

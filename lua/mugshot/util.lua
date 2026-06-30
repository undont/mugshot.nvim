-- shared git/remote helpers

local M = {}

-- owner/repo from an origin url; handles ssh and https, trailing .git,
-- and dots in the repo name (e.g. mugshot.nvim)
---@param remote string
---@return string?
function M.slug_from_remote(remote)
    if not remote or remote == "" then
        return nil
    end
    local path = remote:match("github%.com[:/](.+)$")
    if not path then
        return nil
    end
    path = path:gsub("%.git$", "")
    local owner, repo = path:match("^([^/]+)/([^/]+)")
    if not owner or not repo then
        return nil
    end
    return owner .. "/" .. repo
end

-- resolve owner/repo for a working dir, async
---@param cwd string
---@param cb fun(slug: string?)
function M.repo_slug(cwd, cb)
    vim.system({ "git", "remote", "get-url", "origin" }, { cwd = cwd, text = true }, function(r)
        cb(M.slug_from_remote(vim.trim(r.stdout or "")))
    end)
end

return M

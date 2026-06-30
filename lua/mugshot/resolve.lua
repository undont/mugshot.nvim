-- author -> avatar url, github first then gravatar then placeholder. async.
-- ported from .spikes/spike2-avatar-resolve.sh

local util = require("mugshot.util")

local M = {}

---@class mugshot.Avatar
---@field url string?  nil when source is "placeholder"
---@field login string?  github login when resolved via github
---@field source "github"|"gravatar"|"placeholder"

M._slug_from_remote = util.slug_from_remote

---@param email string
---@param size integer
---@return string
local function gravatar_url(email, size)
    local hash = vim.fn.sha256(vim.trim(email):lower())
    return ("https://gravatar.com/avatar/%s?s=%d&d=404"):format(hash, size)
end

-- resolve an avatar for a commit. the github lookup is the only rate-limited
-- call (5k/hr authed) and is skipped for the all-zero unpushed sha.
---@param opts { sha:string, email:string, cwd:string, size?:integer }
---@param cb fun(avatar: mugshot.Avatar)
function M.resolve(opts, cb)
    local size = opts.size or 128
    local function finish(a)
        vim.schedule(function()
            cb(a)
        end)
    end

    local function try_gravatar()
        if not opts.email or opts.email == "" then
            return finish({ source = "placeholder" })
        end
        local url = gravatar_url(opts.email, size)
        vim.system(
            { "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", url },
            { text = true },
            function(res)
                if vim.trim(res.stdout or "") == "200" then
                    finish({ url = url, source = "gravatar" })
                else
                    finish({ source = "placeholder" })
                end
            end
        )
    end

    local unpushed = opts.sha and opts.sha:match("^0+$") ~= nil
    util.repo_slug(opts.cwd, function(slug)
        if not slug or unpushed then
            return try_gravatar()
        end
        vim.system({
            "gh",
            "api",
            "repos/" .. slug .. "/commits/" .. opts.sha,
            "--jq",
            "{login: .author.login, avatar: .author.avatar_url}",
        }, { cwd = opts.cwd, text = true }, function(g)
            if g.code == 0 then
                local ok, obj = pcall(vim.json.decode, vim.trim(g.stdout or ""))
                if
                    ok
                    and type(obj) == "table"
                    and obj.avatar
                    and obj.avatar ~= vim.NIL
                    and obj.avatar ~= ""
                then
                    return finish({
                        url = obj.avatar .. "&s=" .. size,
                        login = (obj.login ~= vim.NIL) and obj.login or nil,
                        source = "github",
                    })
                end
            end
            try_gravatar()
        end)
    end)
end

return M

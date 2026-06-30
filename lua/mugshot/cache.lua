-- disk cache for avatar pngs: async download + magick pre-resize.
-- keyed by github login when known so a contributor's later commits reuse the
-- face; falls back to a hash of the url

local config = require("mugshot.config")

local M = {}

---@param avatar mugshot.Avatar
---@return string
local function key_for(avatar)
    if avatar.login then
        return "gh-" .. avatar.login
    end
    return "url-" .. vim.fn.sha256(avatar.url):sub(1, 16)
end

M._key_for = key_for

-- return a local png path for an avatar, downloading + resizing on a miss.
-- calls back with nil if there's no url (placeholder) or a step fails
---@param avatar mugshot.Avatar
---@param cb fun(path: string?)
function M.fetch(avatar, cb)
    if not avatar or not avatar.url then
        return cb(nil)
    end

    local opts = config.options
    local dir = opts.cache.dir
    vim.fn.mkdir(dir, "p")

    local path = ("%s/%s.png"):format(dir, key_for(avatar))
    if vim.fn.filereadable(path) == 1 then
        return cb(path)
    end

    local size = opts.avatar.size
    vim.system({ "curl", "-fsSL", avatar.url, "-o", path }, { text = true }, function(dl)
        if dl.code ~= 0 then
            return vim.schedule(function()
                cb(nil)
            end)
        end
        -- normalise to a clean square png; magick is image.nvim's dep anyway
        local geom = ("%dx%d"):format(size, size)
        vim.system(
            { "magick", path, "-resize", geom .. "^", "-gravity", "center", "-extent", geom, path },
            { text = true },
            function(mg)
                vim.schedule(function()
                    cb(mg.code == 0 and path or nil)
                end)
            end
        )
    end)
end

return M

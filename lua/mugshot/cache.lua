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

-- generate (once) a neutral avatar silhouette for commits with no resolvable
-- face (unpushed local commits, no gravatar). drawn with magick so there's no
-- binary asset to ship; cached at the configured avatar size
---@param cb fun(path: string?)
function M.placeholder(cb)
    local opts = config.options
    local dir = opts.cache.dir
    vim.fn.mkdir(dir, "p")

    local s = opts.avatar.size
    local path = ("%s/placeholder-%d.png"):format(dir, s)
    if vim.fn.filereadable(path) == 1 then
        return cb(path)
    end

    local cx = math.floor(s / 2)
    local head_r = math.floor(s * 0.17)
    local head_y = math.floor(s * 0.40)
    local body_ry = math.floor(s * 0.26)
    local body_rx = math.floor(body_ry * 1.6)
    vim.system({
        "magick",
        "-size",
        ("%dx%d"):format(s, s),
        "xc:#3b4252",
        "-fill",
        "#6c7086",
        "-draw",
        ("circle %d,%d %d,%d"):format(cx, head_y, cx, head_y - head_r),
        "-draw",
        ("ellipse %d,%d %d,%d 0,360"):format(cx, s, body_rx, body_ry),
        path,
    }, { text = true }, function(res)
        vim.schedule(function()
            cb(res.code == 0 and path or nil)
        end)
    end)
end

return M

-- single-line `git blame --porcelain` parse for the current line

local M = {}

---@class mugshot.BlameInfo
---@field sha string
---@field abbrev string
---@field author string
---@field author_mail string
---@field author_time integer
---@field committer string
---@field committer_mail string
---@field committer_time integer
---@field summary string
---@field filename string
---@field uncommitted boolean  true for the all-zero sha (not committed yet)

---@param mail string
---@return string
local function strip_brackets(mail)
    return (mail:gsub("^<", ""):gsub(">$", ""))
end

-- parse the porcelain block for a single line; the header line is
-- `<sha> <orig> <final> <count>` followed by key/value lines
---@param out string
---@return mugshot.BlameInfo?
local function parse(out)
    local sha = out:match("^(%x+)")
    if not sha then
        return nil
    end

    local info = { sha = sha }
    for line in vim.gsplit(out, "\n", { plain = true }) do
        local key, val = line:match("^(%S+) (.*)$")
        if key == "author" then
            info.author = val
        elseif key == "author-mail" then
            info.author_mail = strip_brackets(val)
        elseif key == "author-time" then
            info.author_time = tonumber(val)
        elseif key == "committer" then
            info.committer = val
        elseif key == "committer-mail" then
            info.committer_mail = strip_brackets(val)
        elseif key == "committer-time" then
            info.committer_time = tonumber(val)
        elseif key == "summary" then
            info.summary = val
        elseif key == "filename" then
            info.filename = val
        end
    end

    info.abbrev = sha:sub(1, 7)
    info.uncommitted = sha:match("^0+$") ~= nil
    return info
end

M._parse = parse

-- blame a single line of a saved file; runs git async, calls back on the main loop.
-- note: blames the on-disk file, so unsaved buffer edits can shift line numbers
---@param file string  absolute path
---@param lnum integer  1-based line
---@param cb fun(info: mugshot.BlameInfo?, err: string?)
function M.blame_line(file, lnum, cb)
    vim.system(
        { "git", "blame", "-L", lnum .. "," .. lnum, "--porcelain", "--", file },
        { cwd = vim.fs.dirname(file), text = true },
        function(res)
            vim.schedule(function()
                if res.code ~= 0 then
                    return cb(nil, vim.trim(res.stderr or ("git blame exited " .. res.code)))
                end
                cb(parse(res.stdout))
            end)
        end
    )
end

return M

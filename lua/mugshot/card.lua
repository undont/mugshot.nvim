-- the blame card: a focusable float with text rows and, when the terminal can
-- draw it, an author avatar in the left block. productionised from
-- .spikes/spike1-init.lua

local config = require("mugshot.config")
local capability = require("mugshot.capability")
local resolve = require("mugshot.resolve")
local cache = require("mugshot.cache")
local github = require("mugshot.github")

local M = {}

---@param epoch integer
---@return string
local function rel_time(epoch)
    local d = os.time() - epoch
    if d < 0 then
        d = 0
    end
    local function ago(n, word)
        n = math.floor(n)
        return ("%d %s%s ago"):format(n, word, n == 1 and "" or "s")
    end
    if d < 60 then
        return ago(d, "second")
    end
    if d < 3600 then
        return ago(d / 60, "minute")
    end
    if d < 86400 then
        return ago(d / 3600, "hour")
    end
    if d < 86400 * 7 then
        return ago(d / 86400, "day")
    end
    if d < 86400 * 30 then
        return ago(d / (86400 * 7), "week")
    end
    if d < 86400 * 365 then
        return ago(d / (86400 * 30), "month")
    end
    return ago(d / (86400 * 365), "year")
end

local ns = vim.api.nvim_create_namespace("mugshot")

-- default, user-overridable highlight groups for the card rows
local hl_done = false
local function ensure_hl()
    if hl_done then
        return
    end
    hl_done = true
    local function def(name, link)
        vim.api.nvim_set_hl(0, name, { link = link, default = true })
    end
    def("MugshotAuthor", "Title")
    def("MugshotHash", "Identifier")
    def("MugshotTime", "Comment")
    def("MugshotSummary", "Normal")
    def("MugshotIcon", "Special")
    def("MugshotHint", "Comment")
end

---@class mugshot.CardHighlight
---@field line integer  0-based row
---@field col_start integer  byte column
---@field col_end integer  byte column
---@field group string

---@param info mugshot.BlameInfo
---@param cap mugshot.Capability
---@param opts mugshot.Config
---@return { lines: string[], highlights: mugshot.CardHighlight[] }
local function build_card(info, cap, opts)
    local pad = cap.ok and string.rep(" ", opts.avatar.width + 2) or ""
    local t = info.author_time or os.time()
    local when = ("%s (%s)"):format(rel_time(t), os.date("%Y-%m-%d %H:%M", t))
    local icons = opts.icons or {}

    local lines, hls = {}, {}
    -- append a row: an optional leading icon then { text, group, gap } segments,
    -- recording a byte-range highlight for the icon and each grouped segment
    local function emit(lead, icon, segments)
        local line = lead
        local col = #line
        local ranges = {}
        if icon and icon ~= "" then
            line = line .. icon .. " "
            ranges[#ranges + 1] = { col, col + #icon, "MugshotIcon" }
            col = #line
        end
        for _, seg in ipairs(segments) do
            if seg.gap then
                line = line .. seg.gap
                col = #line
            end
            local start = col
            line = line .. seg.text
            col = #line
            if seg.group and seg.text ~= "" then
                ranges[#ranges + 1] = { start, col, seg.group }
            end
        end
        local row = #lines
        lines[#lines + 1] = line
        for _, r in ipairs(ranges) do
            hls[#hls + 1] = { line = row, col_start = r[1], col_end = r[2], group = r[3] }
        end
    end

    emit(pad, icons.author, {
        { text = info.author, group = "MugshotAuthor" },
        { text = when, group = "MugshotTime", gap = "  " },
    })
    emit(pad, icons.hash, { { text = info.abbrev, group = "MugshotHash" } })
    emit(pad, icons.summary, { { text = info.summary or "", group = "MugshotSummary" } })

    -- keep the card tall enough for the avatar block
    while cap.ok and #lines < opts.avatar.height + 1 do
        lines[#lines + 1] = ""
    end
    if opts.hint_row then
        local a = opts.actions
        local dismiss = type(a.dismiss) == "table" and a.dismiss[1] or a.dismiss
        lines[#lines + 1] = ""
        local hint = ("%s open · %s copy · %s pr · %s close"):format(
            a.open_commit,
            a.copy_sha,
            a.open_pr,
            dismiss
        )
        emit("", nil, { { text = hint, group = "MugshotHint" } })
    end
    return { lines = lines, highlights = hls }
end

---@param info mugshot.BlameInfo
---@param cap mugshot.Capability
---@param opts mugshot.Config
---@return string[]
local function build_lines(info, cap, opts)
    return build_card(info, cap, opts).lines
end

-- open the card for a parsed blame line; resolves and draws the avatar async
---@param info mugshot.BlameInfo
---@param cwd string
function M.open(info, cwd)
    local opts = config.options
    local cap = capability.detect()
    ensure_hl()
    local built = build_card(info, cap, opts)
    local lines = built.lines

    local width = 40
    for _, l in ipairs(lines) do
        width = math.max(width, vim.fn.strdisplaywidth(l) + 1)
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    for _, h in ipairs(built.highlights) do
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, h.line, h.col_start, {
            end_col = h.col_end,
            hl_group = h.group,
        })
    end
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "mugshot"

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "cursor",
        row = 1,
        col = 0,
        width = width,
        height = #lines,
        style = "minimal",
        border = "rounded",
        title = " blame ",
        title_pos = "left",
    })

    local img
    local function close()
        if img then
            pcall(function()
                img:clear()
            end)
        end
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    local a = opts.actions
    local function map(lhs, fn)
        for _, k in ipairs(type(lhs) == "table" and lhs or { lhs }) do
            if k then
                vim.keymap.set("n", k, fn, { buffer = buf, nowait = true, silent = true })
            end
        end
    end
    map(a.dismiss, close)
    map(a.open_commit, function()
        github.open_commit(info, cwd)
    end)
    map(a.copy_sha, function()
        github.copy_sha(info.sha)
    end)
    map(a.open_pr, function()
        github.open_pr(info, cwd)
    end)

    -- dismiss when focus leaves the card
    vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = close })

    if cap.ok and not info.uncommitted then
        local function render(path)
            if not path or not vim.api.nvim_win_is_valid(win) then
                return
            end
            img = require("image").from_file(path, {
                window = win,
                buffer = buf,
                x = 1,
                y = 1,
                width = opts.avatar.width,
                height = opts.avatar.height,
            })
            pcall(function()
                img:render()
            end)
            vim.api.nvim_create_autocmd({ "WinScrolled", "VimResized" }, {
                buffer = buf,
                callback = function()
                    pcall(function()
                        img:render()
                    end)
                end,
            })
        end

        resolve.resolve(
            { sha = info.sha, email = info.author_mail, cwd = cwd, size = opts.avatar.size },
            function(av)
                -- a resolved face, else the generated placeholder silhouette
                cache.fetch(av, function(path)
                    if path then
                        render(path)
                    else
                        cache.placeholder(render)
                    end
                end)
            end
        )
    end

    return win, buf
end

M._build_lines = build_lines
M._build_card = build_card
M._rel_time = rel_time

return M

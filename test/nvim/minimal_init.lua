-- busted helper for the headless-nvim suite (wired via .busted `nvim.helper`).
-- captures notifications into `_G.notifs` so they don't leak into progress
-- output; specs can inspect the table when asserting on a message
_G.notifs = {}
vim.notify = function(msg, level)
    _G.notifs[#_G.notifs + 1] = { msg = msg, level = level }
end

-- swap a field on a table for the duration of fn, then restore it.
-- the workhorse for stubbing vim.system / vim.ui.open / util.repo_slug in specs
---@param tbl table
---@param key any
---@param value any
---@param fn fun()
_G.with = function(tbl, key, value, fn)
    local orig = tbl[key]
    tbl[key] = value
    local ok, err = pcall(fn)
    tbl[key] = orig
    if not ok then
        error(err)
    end
end

-- a fake vim.system: matches each call against a list of { match, result }
-- rules by substring of the joined argv, and invokes on_exit with the result.
-- supports both async (on_exit) and sync (:wait()) call shapes
---@param rules { match: string, result: table }[]
---@return function
_G.fake_system = function(rules)
    return function(cmd, _opts, on_exit)
        local joined = table.concat(cmd, " ")
        local result = { code = 0, stdout = "", stderr = "" }
        for _, rule in ipairs(rules) do
            if joined:find(rule.match, 1, true) then
                result = vim.tbl_extend("force", result, rule.result)
                break
            end
        end
        if on_exit then
            on_exit(result)
            return {
                wait = function()
                    return result
                end,
            }
        end
        return {
            wait = function()
                return result
            end,
        }
    end
end

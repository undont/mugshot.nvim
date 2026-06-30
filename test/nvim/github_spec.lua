local github = require("mugshot.github")
local util = require("mugshot.util")

local function last_notif()
    return _G.notifs[#_G.notifs]
end

describe("github.copy_sha", function()
    it("writes the full sha to the unnamed register", function()
        github.copy_sha("deadbeefcafebabe1234")
        assert.are.equal("deadbeefcafebabe1234", vim.fn.getreg('"'))
        assert.is_truthy(last_notif().msg:find("copied", 1, true))
    end)
end)

describe("github.open_commit", function()
    it("opens the commit url for a committed line", function()
        local opened
        with(util, "repo_slug", function(_, cb)
            cb("undont/mugshot.nvim")
        end, function()
            with(vim.ui, "open", function(url)
                opened = url
            end, function()
                github.open_commit({ sha = "abc123", uncommitted = false }, "/repo")
                vim.wait(500, function()
                    return opened ~= nil
                end)
            end)
        end)
        assert.are.equal("https://github.com/undont/mugshot.nvim/commit/abc123", opened)
    end)

    it("refuses an uncommitted line and does not open anything", function()
        local opened
        with(vim.ui, "open", function(url)
            opened = url
        end, function()
            github.open_commit({ uncommitted = true }, "/repo")
            vim.wait(50)
        end)
        assert.is_nil(opened)
        assert.is_truthy(last_notif().msg:find("not committed", 1, true))
    end)

    it("warns when there is no github origin", function()
        with(util, "repo_slug", function(_, cb)
            cb(nil)
        end, function()
            github.open_commit({ sha = "x", uncommitted = false }, "/repo")
            vim.wait(200, function()
                return false
            end)
        end)
        assert.is_truthy(last_notif().msg:find("no github origin", 1, true))
    end)
end)

describe("github.open_pr", function()
    it("opens the PR url when gh finds one", function()
        local opened
        with(util, "repo_slug", function(_, cb)
            cb("o/r")
        end, function()
            with(
                vim,
                "system",
                fake_system({
                    {
                        match = "pulls",
                        result = { code = 0, stdout = "https://github.com/o/r/pull/7\n" },
                    },
                }),
                function()
                    with(vim.ui, "open", function(url)
                        opened = url
                    end, function()
                        github.open_pr(
                            { sha = "abc", abbrev = "abc", uncommitted = false },
                            "/repo"
                        )
                        vim.wait(500, function()
                            return opened ~= nil
                        end)
                    end)
                end
            )
        end)
        assert.are.equal("https://github.com/o/r/pull/7", opened)
    end)

    it("falls back to the commit url when gh returns no PR", function()
        local opened
        with(util, "repo_slug", function(_, cb)
            cb("o/r")
        end, function()
            with(
                vim,
                "system",
                fake_system({
                    { match = "pulls", result = { code = 0, stdout = "" } },
                }),
                function()
                    with(vim.ui, "open", function(url)
                        opened = url
                    end, function()
                        github.open_pr(
                            { sha = "abc", abbrev = "abc", uncommitted = false },
                            "/repo"
                        )
                        vim.wait(500, function()
                            return opened ~= nil
                        end)
                    end)
                end
            )
        end)
        assert.are.equal("https://github.com/o/r/commit/abc", opened)
    end)
end)

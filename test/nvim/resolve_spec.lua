local resolve = require("mugshot.resolve")
local util = require("mugshot.util")

-- drive resolve.resolve with a stubbed slug lookup and a fake vim.system
---@param opts table
---@param rules table
---@param slug string?
local function run(opts, rules, slug)
    local result
    with(util, "repo_slug", function(_, cb)
        cb(slug)
    end, function()
        with(vim, "system", fake_system(rules), function()
            resolve.resolve(opts, function(a)
                result = a
            end)
            vim.wait(1000, function()
                return result ~= nil
            end)
        end)
    end)
    return result
end

describe("resolve.resolve", function()
    it("resolves via github when the commit has a linked user", function()
        local a = run({ sha = "abc", email = "s@e.com", cwd = "/r", size = 128 }, {
            {
                match = "gh api",
                result = {
                    code = 0,
                    stdout = '{"login":"undont","avatar":"https://avatars.githubusercontent.com/u/1?v=4"}',
                },
            },
        }, "undont/mugshot.nvim")
        assert.are.equal("github", a.source)
        assert.are.equal("undont", a.login)
        assert.are.equal("https://avatars.githubusercontent.com/u/1?v=4&s=128", a.url)
    end)

    it("falls back to gravatar when github has no linked user", function()
        local a = run({ sha = "abc", email = "s@e.com", cwd = "/r", size = 128 }, {
            { match = "gh api", result = { code = 0, stdout = '{"login":null,"avatar":null}' } },
            { match = "curl", result = { code = 0, stdout = "200" } },
        }, "o/r")
        assert.are.equal("gravatar", a.source)
        assert.is_truthy(a.url:find("gravatar.com/avatar/", 1, true))
    end)

    it("uses a placeholder when gravatar 404s", function()
        local a = run({ sha = "abc", email = "s@e.com", cwd = "/r", size = 128 }, {
            { match = "gh api", result = { code = 0, stdout = '{"login":null,"avatar":null}' } },
            { match = "curl", result = { code = 0, stdout = "404" } },
        }, "o/r")
        assert.are.equal("placeholder", a.source)
        assert.is_nil(a.url)
    end)

    it("skips github for an all-zero unpushed sha", function()
        local a = run({
            sha = "0000000000000000000000000000000000000000",
            email = "s@e.com",
            cwd = "/r",
            size = 128,
        }, { { match = "curl", result = { code = 0, stdout = "200" } } }, "o/r")
        assert.are.equal("gravatar", a.source)
    end)

    it("skips github when there is no origin slug", function()
        local a = run(
            { sha = "abc", email = "s@e.com", cwd = "/r", size = 128 },
            { { match = "curl", result = { code = 0, stdout = "200" } } },
            nil
        )
        assert.are.equal("gravatar", a.source)
    end)

    it("uses a placeholder when there is no email and github fails", function()
        local a = run(
            { sha = "abc", email = "", cwd = "/r", size = 128 },
            { { match = "gh api", result = { code = 0, stdout = '{"login":null,"avatar":null}' } } },
            "o/r"
        )
        assert.are.equal("placeholder", a.source)
    end)
end)

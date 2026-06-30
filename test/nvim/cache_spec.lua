local cache = require("mugshot.cache")
local config = require("mugshot.config")

describe("cache._key_for", function()
    it("keys by github login when present", function()
        assert.are.equal("gh-undont", cache._key_for({ login = "undont", url = "x" }))
    end)

    it("keys by a url hash otherwise", function()
        local k = cache._key_for({ url = "http://x/a.png" })
        assert.is_truthy(k:find("^url%-"))
        assert.are.equal(20, #k) -- "url-" + 16 hex chars
    end)
end)

describe("cache.fetch", function()
    local dir

    before_each(function()
        dir = vim.fn.tempname()
        config.setup({ cache = { dir = dir } })
    end)

    it("returns nil for a placeholder avatar with no url", function()
        local called, res = false, "unset"
        cache.fetch({ source = "placeholder" }, function(p)
            called, res = true, p
        end)
        assert.is_true(called)
        assert.is_nil(res)
    end)

    it("returns the cached path without shelling out on a hit", function()
        vim.fn.mkdir(dir, "p")
        local path = dir .. "/gh-undont.png"
        vim.fn.writefile({ "x" }, path)
        local called, res = false, nil
        with(vim, "system", function()
            called = true
            return {
                wait = function()
                    return {}
                end,
            }
        end, function()
            cache.fetch({ url = "http://x", login = "undont", source = "github" }, function(p)
                res = p
            end)
        end)
        assert.are.equal(path, res)
        assert.is_false(called)
    end)

    it("downloads then resizes on a miss and returns the path", function()
        local res, done
        with(
            vim,
            "system",
            fake_system({
                { match = "curl", result = { code = 0 } },
                { match = "magick", result = { code = 0 } },
            }),
            function()
                cache.fetch(
                    { url = "http://x/a.png", login = "undont", source = "github" },
                    function(p)
                        res, done = p, true
                    end
                )
                vim.wait(500, function()
                    return done
                end)
            end
        )
        assert.are.equal(dir .. "/gh-undont.png", res)
    end)

    it("returns nil when the download fails", function()
        local res, done = "unset", false
        with(vim, "system", fake_system({ { match = "curl", result = { code = 7 } } }), function()
            cache.fetch({ url = "http://x", login = "undont", source = "github" }, function(p)
                res, done = p, true
            end)
            vim.wait(500, function()
                return done
            end)
        end)
        assert.is_true(done)
        assert.is_nil(res)
    end)
end)

local util = require("mugshot.util")

describe("util.slug_from_remote", function()
    it("parses an ssh remote with a dotted repo name and trailing .git", function()
        assert.are.equal(
            "undont/mugshot.nvim",
            util.slug_from_remote("git@github.com:undont/mugshot.nvim.git")
        )
    end)

    it("parses an https remote", function()
        assert.are.equal(
            "undont/mugshot.nvim",
            util.slug_from_remote("https://github.com/undont/mugshot.nvim")
        )
    end)

    it("strips a trailing .git on https", function()
        assert.are.equal(
            "undont/mugshot.nvim",
            util.slug_from_remote("https://github.com/undont/mugshot.nvim.git")
        )
    end)

    it("handles a plain repo name", function()
        assert.are.equal("foo/bar", util.slug_from_remote("git@github.com:foo/bar"))
    end)

    it("takes only the first two path segments", function()
        assert.are.equal("foo/bar", util.slug_from_remote("https://github.com/foo/bar/extra"))
    end)

    it("tolerates a trailing slash", function()
        assert.are.equal("foo/bar", util.slug_from_remote("https://github.com/foo/bar/"))
    end)

    it("returns nil for a non-github host", function()
        assert.is_nil(util.slug_from_remote("https://gitlab.com/x/y.git"))
    end)

    it("returns nil for an empty or nil remote", function()
        assert.is_nil(util.slug_from_remote(""))
        assert.is_nil(util.slug_from_remote(nil))
    end)
end)

local blame = require("mugshot.blame")

local PORCELAIN = table.concat({
    "1a2b3c4d5e6f7a8b 12 12 1",
    "author Sean",
    "author-mail <sean@example.com>",
    "author-time 1700000000",
    "author-tz +0000",
    "committer Someone Else",
    "committer-mail <else@example.com>",
    "committer-time 1700000050",
    "committer-tz +0000",
    "summary did a thing",
    "previous 0badc0de lua/x.lua",
    "filename lua/x.lua",
    "\tlocal x = 1",
}, "\n")

describe("blame._parse", function()
    it("pulls the sha and a 7-char abbrev from the header", function()
        local info = blame._parse(PORCELAIN)
        assert.are.equal("1a2b3c4d5e6f7a8b", info.sha)
        assert.are.equal("1a2b3c4", info.abbrev)
    end)

    it("parses author and committer, stripping the mail brackets", function()
        local info = blame._parse(PORCELAIN)
        assert.are.equal("Sean", info.author)
        assert.are.equal("sean@example.com", info.author_mail)
        assert.are.equal("Someone Else", info.committer)
        assert.are.equal("else@example.com", info.committer_mail)
    end)

    it("parses the times as numbers and the summary verbatim", function()
        local info = blame._parse(PORCELAIN)
        assert.are.equal(1700000000, info.author_time)
        assert.are.equal(1700000050, info.committer_time)
        assert.are.equal("did a thing", info.summary)
        assert.are.equal("lua/x.lua", info.filename)
    end)

    it("flags the all-zero sha as uncommitted", function()
        local out =
            "0000000000000000000000000000000000000000 1 1 1\nauthor Not Committed Yet\nsummary x\n"
        local info = blame._parse(out)
        assert.is_true(info.uncommitted)
        assert.are.equal("Not Committed Yet", info.author)
    end)

    it("treats a real sha as committed", function()
        assert.is_false(blame._parse(PORCELAIN).uncommitted)
    end)

    it("returns nil when there is no leading sha", function()
        assert.is_nil(blame._parse(""))
        assert.is_nil(blame._parse("not a porcelain block\n"))
    end)
end)

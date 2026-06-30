local card = require("mugshot.card")
local config = require("mugshot.config")

before_each(function()
    config.setup()
end)

describe("card._rel_time", function()
    it("renders singular and plural units", function()
        assert.are.equal("1 second ago", card._rel_time(os.time() - 1))
        assert.is_truthy(card._rel_time(os.time() - 7200):find("2 hours ago", 1, true))
        assert.is_truthy(card._rel_time(os.time() - 86400 * 3):find("3 days ago", 1, true))
    end)

    it("clamps a future time to zero", function()
        assert.are.equal("0 seconds ago", card._rel_time(os.time() + 1000))
    end)
end)

describe("card._build_lines", function()
    local info = {
        author = "Sean",
        abbrev = "deadbee",
        summary = "did things",
        author_time = os.time() - 3600,
        sha = "deadbeefcafe",
        uncommitted = false,
    }

    it("has no left pad in text mode", function()
        local lines = card._build_lines(info, { ok = false }, config.options)
        assert.is_nil(lines[1]:find("^ "))
        assert.is_truthy(lines[1]:find("Sean", 1, true))
        assert.is_truthy(lines[2]:find("deadbee", 1, true))
        assert.is_truthy(lines[3]:find("did things", 1, true))
    end)

    it("left-pads the rows and stays tall enough in avatar mode", function()
        local lines = card._build_lines(info, { ok = true }, config.options)
        assert.is_truthy(lines[1]:find("^%s%s+"))
        assert.is_truthy(lines[1]:find("Sean", 1, true))
        assert.is_true(#lines >= config.options.avatar.height + 1)
    end)

    it("prefixes the rows with icons by default and drops them when icons=false", function()
        local with = card._build_lines(info, { ok = false }, config.options)
        assert.is_truthy(with[2]:find(config.options.icons.hash, 1, true))
        config.setup({ icons = false })
        local without = card._build_lines(info, { ok = false }, config.options)
        assert.are.equal("deadbee", without[2])
    end)

    it("emits a byte-range highlight for the hash row", function()
        local built = card._build_card(info, { ok = false }, config.options)
        local found = false
        for _, h in ipairs(built.highlights) do
            if h.group == "MugshotHash" then
                found = true
                assert.is_true(h.col_end > h.col_start)
            end
        end
        assert.is_true(found)
    end)

    it("ends with a hint row built from the configured keys", function()
        local hint = card._build_lines(info, { ok = false }, config.options)
        hint = hint[#hint]
        assert.is_truthy(hint:find("o open", 1, true))
        assert.is_truthy(hint:find("y copy", 1, true))
        assert.is_truthy(hint:find("p pr", 1, true))
        assert.is_truthy(hint:find("q close", 1, true))
    end)

    it("omits the hint row when disabled", function()
        config.setup({ hint_row = false })
        local lines = card._build_lines(info, { ok = false }, config.options)
        assert.is_falsy(lines[#lines]:find("open", 1, true))
    end)
end)

describe("card.open", function()
    local info = {
        author = "Sean",
        abbrev = "deadbee",
        summary = "scaffold",
        author_time = os.time() - 60,
        sha = "deadbeefcafe0000",
        author_mail = "s@e.com",
        uncommitted = false,
    }

    it("opens a focusable float and enters it", function()
        local win = card.open(info, vim.fn.getcwd())
        assert.is_true(vim.api.nvim_win_is_valid(win))
        assert.are.equal(win, vim.api.nvim_get_current_win())
        vim.api.nvim_win_close(win, true)
    end)

    it("binds the action and dismiss keys buffer-locally", function()
        local win, buf = card.open(info, vim.fn.getcwd())
        local maps = {}
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
            maps[m.lhs] = true
        end
        for _, k in ipairs({ "o", "y", "p", "q" }) do
            assert.is_true(maps[k] == true)
        end
        assert.is_true(maps["<Esc>"] == true)
        vim.api.nvim_win_close(win, true)
    end)
end)

local capability = require("mugshot.capability")

local KEYS = {
    "MUGSHOT_FORCE_KITTY",
    "KITTY_WINDOW_ID",
    "GHOSTTY_RESOURCES_DIR",
    "GHOSTTY_BIN_DIR",
    "WEZTERM_PANE",
    "TERM_PROGRAM",
    "TERM",
}

local saved

local function clear_all()
    for _, k in ipairs(KEYS) do
        vim.env[k] = nil
    end
end

describe("capability._kitty_capable", function()
    before_each(function()
        saved = {}
        for _, k in ipairs(KEYS) do
            saved[k] = vim.env[k]
        end
        clear_all()
    end)
    after_each(function()
        for _, k in ipairs(KEYS) do
            vim.env[k] = saved[k]
        end
    end)

    it("is false with no terminal markers at all", function()
        assert.is_false(capability._kitty_capable())
    end)

    it("detects ghostty via an env var that survives tmux", function()
        vim.env.GHOSTTY_RESOURCES_DIR = "/Applications/Ghostty.app/Contents/Resources/ghostty"
        assert.is_true(capability._kitty_capable())
    end)

    it("detects kitty via KITTY_WINDOW_ID", function()
        vim.env.KITTY_WINDOW_ID = "1"
        assert.is_true(capability._kitty_capable())
    end)

    it("detects wezterm via WEZTERM_PANE", function()
        vim.env.WEZTERM_PANE = "0"
        assert.is_true(capability._kitty_capable())
    end)

    it("honours the MUGSHOT_FORCE_KITTY override", function()
        vim.env.MUGSHOT_FORCE_KITTY = "1"
        assert.is_true(capability._kitty_capable())
    end)

    it("falls back to TERM_PROGRAM outside tmux", function()
        vim.env.TERM_PROGRAM = "ghostty"
        assert.is_true(capability._kitty_capable())
    end)

    it("rejects a plain terminal", function()
        vim.env.TERM = "xterm-256color"
        vim.env.TERM_PROGRAM = "Apple_Terminal"
        assert.is_false(capability._kitty_capable())
    end)
end)

describe("capability.detect", function()
    it("memoises the verdict until forced", function()
        local a = capability.detect(true)
        local b = capability.detect()
        assert.are.equal(a, b)
    end)
end)

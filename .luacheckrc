---@diagnostic disable: lowercase-global
unused_args = false
globals = { "vim" }
read_globals = {
    "describe",
    "it",
    "before_each",
    "after_each",
    "setup",
    "teardown",
    "pending",
    "assert",
    "stub",
    "spy",
    "mock",
    -- test helpers defined in test/nvim/minimal_init.lua
    "with",
    "fake_system",
}

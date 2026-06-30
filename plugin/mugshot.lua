-- the :Mugshot command works without setup() (config has load-time defaults);
-- setup() is only needed to bind the trigger keymap

if vim.g.loaded_mugshot then
    return
end
vim.g.loaded_mugshot = true

vim.api.nvim_create_user_command("Mugshot", function()
    require("mugshot").show()
end, { desc = "mugshot: blame card for the current line" })

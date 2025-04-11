-- This will run last in the setup process and is a good place to configure
-- things like custom filetypes. This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- Set up custom filetypes
-- vim.filetype.add {
--   extension = {
--     foo = "fooscript",
--   },
--   filename = {
--     ["Foofile"] = "fooscript",
--   },
--   pattern = {
--     ["~/%.config/foo/.*"] = "fooscript",
--   },
-- }

-- Disable arrow keys
vim.keymap.set("", "<Up>", "<nop>", { noremap = true })
vim.keymap.set("", "<Down>", "<nop>", { noremap = true })
vim.keymap.set("", "<Left>", "<nop>", { noremap = true })
vim.keymap.set("", "<Right>", "<nop>", { noremap = true })

vim.keymap.set("i", "<Up>", "<nop>", { noremap = true })
vim.keymap.set("i", "<Down>", "<nop>", { noremap = true })
vim.keymap.set("i", "<Left>", "<nop>", { noremap = true })
vim.keymap.set("i", "<Right>", "<nop>", { noremap = true })

-- Disable mouse drag
vim.keymap.set("", "<LeftDrag>", "<nop>", { noremap = true })
vim.keymap.set("", "<LeftRelease>", "<nop>", { noremap = true })

-- Vertical Movement
vim.keymap.set("", "<C-d>", "<C-d>zz", { noremap = true })
vim.keymap.set("", "<C-u>", "<C-u>zz", { noremap = true })
vim.keymap.set("", "n", "nzzzv", { noremap = true })
vim.keymap.set("", "N", "Nzzzv", { noremap = true })


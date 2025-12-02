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

-- disable arrow keys
vim.keymap.set("i", "<Up>", "<nop>", { noremap = true })
vim.keymap.set("i", "<Down>", "<nop>", { noremap = true })
vim.keymap.set("v", "<Left>", "<nop>", { noremap = true })
vim.keymap.set("v", "<Right>", "<nop>", { noremap = true })

-- disable mouse
vim.keymap.set("", "<LeftDrag>", "<nop>", { noremap = true })
vim.keymap.set("", "<LeftRelease>", "<nop>", { noremap = true })
vim.keymap.set("", "<LeftMouse>", "<nop>", { noremap = true })
vim.keymap.set("", "<2-LeftMouse>", "<nop>", { noremap = true })

-- vertical movement
vim.keymap.set("", "<C-d>", "<C-d>zz", { noremap = true })
vim.keymap.set("", "<C-u>", "<C-u>zz", { noremap = true })
vim.keymap.set("", "n", "nzzzv", { noremap = true })
vim.keymap.set("", "N", "Nzzzv", { noremap = true })

-- file types
vim.filetype.add {
  extension = {
    base = "yaml", -- obsidian base
  },
}

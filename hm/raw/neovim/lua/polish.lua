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

-- restore plugins without touching the lockfile
vim.api.nvim_create_user_command("LazyRestoreNoLockOverwrite", function()
  local lockfile = require("lazy.core.config").options.lockfile
  local f = io.open(lockfile, "rb")
  local old = nil
  if f then
    old = f:read "*a"
    f:close()
  end
  local ok, err = pcall(function() require("lazy").restore { wait = true } end)
  if old ~= nil then
    f = assert(io.open(lockfile, "wb"))
    f:write(old)
    f:close()
  else
    vim.fn.delete(lockfile)
  end
  if not ok then error(err) end
end, {})

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
  pattern = {
    ["sdkconfig%..+"] = "kconfig",
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

-- sync treesitter parsers from plugin configs
vim.api.nvim_create_user_command("TSSync", function()
  local installed = {}
  local languages = {}
  local plugins = require("lazy.core.config").plugins

  local function add(list)
    if type(list) ~= "table" then return end
    for _, lang in ipairs(list) do
      if type(lang) == "string" and not installed[lang] then
        installed[lang] = true
        table.insert(languages, lang)
      end
    end
  end

  for _, plugin in pairs(plugins) do
    if plugin.name == "nvim-treesitter" then
      add(plugin.opts and plugin.opts.ensure_installed)
    elseif plugin.name == "astrocore" then
      add(plugin.opts and plugin.opts.treesitter and plugin.opts.treesitter.ensure_installed)
    end
  end

  if #languages == 0 then return end

  vim.cmd("TSInstall " .. table.concat(languages, " "))
  vim.cmd "TSUpdate"
end, {})

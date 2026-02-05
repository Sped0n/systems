---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      large_buf = { size = 1024 * 512, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics_mode = 3, -- 0 = off, 1 = no signs/virtual text, 2 = no virtual text, 3 = on
      highlighturl = true,
      notifications = true,
    },
    diagnostics = {
      virtual_text = true,
      underline = true,
    },
    options = { -- vim options can be configured here
      opt = {
        relativenumber = true,
        number = true,
        spell = false,
        signcolumn = "yes",
        wrap = false,
        showtabline = 0,
        clipboard = "",
        cursorlineopt = "number",
        mouse = "a",
      },
    },
    mappings = {},
    autocmds = {
      indent = {
        {
          event = "FileType",
          pattern = "cmake",
          callback = function()
            vim.bo.tabstop = 4
            vim.bo.shiftwidth = 4
            vim.bo.expandtab = true
          end,
          desc = "Set tab width to 4 for CMake files",
        },
        {
          event = "FileType",
          pattern = "ld",
          callback = function()
            vim.bo.tabstop = 2
            vim.bo.shiftwidth = 2
            vim.bo.expandtab = true
          end,
          desc = "Set tab width to 2 for linker scripts",
        },
      },
    },
  },
}

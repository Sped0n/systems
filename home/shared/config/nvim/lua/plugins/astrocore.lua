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
    mappings = {
      n = { -- normal mode
        -- buffer navigation
        ["]b"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["[b"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
        ["<Leader>bd"] = {
          function()
            require("astroui.status.heirline").buffer_picker(
              function(bufnr) require("astrocore.buffer").close(bufnr) end
            )
          end,
          desc = "Close buffer from tabline",
        },
        ["<Leader>b"] = { desc = "Buffers" },

        ["<Leader>gB"] = { "<cmd>GitBlameToggle<cr>", desc = "Toggle Git Glame Virtual Text" },
      },
    },
  },
}

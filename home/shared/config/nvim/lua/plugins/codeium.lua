return {
  {
    "Exafunction/codeium.nvim",
    cmd = "Codeium",
    event = "InsertEnter",
    build = ":Codeium Auth",
    opts = {
      enable_chat = false,
    },
  },

  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = {
      icons = {
        Codeium = "󰞋",
      },
    },
  },

  {
    "AstroNvim/astrocore",
    opts = {
      mappings = {
        n = {
          ["<Leader>;"] = {
            desc = "Toggle Codeium Completion",
            function() vim.cmd "Codeium Toggle" end,
          },
        },
      },
    },
  },

  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "codeium" },
        providers = {
          codeium = {
            name = "Codeium",
            module = "codeium.blink",
            async = true,
            transform_items = function(_, items)
              for _, item in ipairs(items) do
                item.kind_icon = require("astroui").get_icon("Codeium", 1, true)
                item.kind_name = "Codeium"
                item.kind_hl = "MiniIconsCyan"
              end
              return items
            end,
          },
        },
      },
    },
  },
}

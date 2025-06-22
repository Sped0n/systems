return {
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
                item.kind_icon = "󰬄"
                item.kind_name = "Codeium"
              end
              return items
            end,
          },
        },
      },
    },
  },

  {
    "Exafunction/codeium.nvim",
    opts = {
      wrapper = (vim.fn.has "linux" == 1 and vim.fn.isdirectory "/nix/store" == 1) and "steam-run" or nil,
    },
  },

  {
    "AstroNvim/astrocore",
    opts = {
      mappings = {
        n = {
          ["<Leader>;t"] = {
            desc = "Toggle Completion",
            function() vim.cmd "Codeium Toggle" end,
          },
        },
      },
    },
  },
}

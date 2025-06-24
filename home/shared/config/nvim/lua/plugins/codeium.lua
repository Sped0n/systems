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
    "AstroNvim/astrocore",
    opts = {
      mappings = {
        n = {
          ["<Leader>;"] = {
            desc = "Toggle Full Codeium Completion",
            function()
              vim.g.codeium_full = not vim.g.codeium_full
              vim.notify("Codeium Full Completion " .. (vim.g.codeium_full and "On" or "Off"), vim.log.levels.INFO)
            end,
          },
        },
      },
    },
  },

  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        default = function(_)
          local success, node = pcall(vim.treesitter.get_node)
          if
            (success and node and (string.find(node:type(), "string") or string.find(node:type(), "comment")))
            or vim.g.codeium_full
          then
            return { "lsp", "path", "snippets", "buffer", "codeium" }
          else
            return { "lsp", "path", "snippets", "buffer" }
          end
        end,
        providers = {
          codeium = {
            name = "Codeium",
            module = "codeium.blink",
            async = true,
            transform_items = function(_, items)
              for _, item in ipairs(items) do
                item.kind_icon = ""
                item.kind_name = "Codeium"
              end
              return items
            end,
          },
        },
      },
    },
  },
}

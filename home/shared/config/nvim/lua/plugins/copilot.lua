---@type LazySpec
return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
      filetypes = {
        markdown = true,
        help = true,
      },
      server = {
        type = "binary",
        custom_server_filepath = vim.fn.exepath "copilot-language-server",
      },
    },
  },
  {
    "saghen/blink.cmp",
    dependencies = {
      "fang2hou/blink-copilot",
    },
    opts = {
      keymap = {
        ["<C-;>"] = {
          function(cmp) cmp.show { providers = { "copilot" } } end,
        },
      },
      sources = {
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-copilot",
            async = true,
          },
        },
      },
    },
  },
}

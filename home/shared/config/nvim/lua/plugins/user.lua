---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            [[                               __                ]],
            [[  ___     ___    ___   __  __ /\_\    ___ ___    ]],
            [[ / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  ]],
            [[/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
            [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
            [[ \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
          }, "\n"),
        },
      },
    },
  },

  { "nvimtools/none-ls.nvim", enabled = false },
  { "williamboman/mason.nvim", enabled = false },
  { "williamboman/mason-lspconfig.nvim", enabled = false },
  { "WhoIsSethDaniel/mason-tool-installer.nvim", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },

  { "olexsmir/gopher.nvim", enabled = false },
  { "mfussenegger/nvim-dap-python", enabled = false },
}

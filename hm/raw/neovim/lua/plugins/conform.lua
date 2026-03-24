---@type LazySpec
return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        nix = { "nixfmt" },
        json = { "prettierd", "jq", stop_after_first = true },
      },
    },
  },
}

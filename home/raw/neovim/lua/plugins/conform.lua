---@type LazySpec
return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        nix = { "nixfmt" },
        json = { "jq", "prettierd", stop_after_first = true },
      },
    },
  },
}

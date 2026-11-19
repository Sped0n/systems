---@type LazySpec
return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.nix = { "nixfmt" }
      opts.formatters_by_ft.json = { "prettierd", "jq", stop_after_first = true }
    end,
  },
}

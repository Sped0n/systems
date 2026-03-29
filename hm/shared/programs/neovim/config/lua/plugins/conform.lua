---@type LazySpec
return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters.astyle_idf = {
        command = "astyle",
        stdin = false,
        condition = function()
          local idf_path = vim.env.IDF_PATH
          if not idf_path or idf_path == "" then return false end

          local rules_path = vim.fs.joinpath(idf_path, "tools", "ci", "astyle-rules.yml")
          return vim.uv.fs_stat(rules_path) ~= nil
        end,
        args = {
          "--style=otbs",
          "--attach-namespaces",
          "--attach-classes",
          "--indent=spaces=4",
          "--convert-tabs",
          "--align-reference=name",
          "--keep-one-line-statements",
          "--pad-header",
          "--pad-oper",
          "--unpad-paren",
          "--max-continuation-indent=120",
          "--suffix=none",
          "$FILENAME",
        },
      }

      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.c = { "astyle_idf", lsp_format = "fallback" }
      opts.formatters_by_ft.cpp = { "astyle_idf", lsp_format = "fallback" }
      opts.formatters_by_ft.nix = { "nixfmt" }
      opts.formatters_by_ft.json = { "prettierd", "jq", stop_after_first = true }
    end,
  },
}

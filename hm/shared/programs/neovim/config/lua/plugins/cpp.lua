---@type LazySpec
return {
  {
    "AstroNvim/astrolsp",
    opts = {
      servers = { "clice", "neocmake" },
      config = {
        clice = {
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, "clice.toml")
              or vim.fs.root(
                bufnr,
                function(name, dir)
                  return name == "compile_commands.json"
                    or (name == "build" and vim.uv.fs_stat(vim.fs.joinpath(dir, name, "compile_commands.json")) ~= nil)
                end
              )
            on_dir(root or vim.fs.root(bufnr, vim.lsp.config.clice.root_markers))
          end,
        },
      },
    },
  },
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      treesitter = { ensure_installed = { "c", "cpp", "cuda", "objc", "proto" } },
    },
  },
  { "Civitasv/cmake-tools.nvim", ft = { "c", "cpp", "objc", "objcpp", "cuda", "proto" }, opts = {} },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters.astyle_idf = {
        command = "astyle",
        stdin = false,
        condition = function(_, ctx)
          local idf_path = vim.env.IDF_PATH
          if not idf_path or idf_path == "" then return false end

          local filename = ctx and ctx.filename or vim.api.nvim_buf_get_name(0)
          local dirname = vim.fs.dirname(filename)
          if dirname and vim.fs.find({ ".clang-format", "_clang-format" }, { path = dirname, upward = true })[1] then
            return false
          end

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
    end,
  },
}

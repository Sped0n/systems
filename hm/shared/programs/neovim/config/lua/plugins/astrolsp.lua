---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@param opts AstroLSPOpts
  opts = function(_, opts)
    opts.features = {
      inlay_hints = true,
      inline_completion = true,
      linked_editing_range = true,
    }

    opts.config.lua_ls = vim.tbl_deep_extend("force", opts.config.lua_ls or {}, {
      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim", "require" },
          },
        },
      },
    })

    opts.servers = opts.servers or {}
    vim.list_extend(opts.servers, {
      -- lua
      "lua_ls",
      -- python
      "basedpyright",
      -- golang
      "gopls",
      -- c/cpp
      "clangd",
      "neocmake",
      -- zig
      "zls",
      -- typescript
      "vtsls",
      "eslint",
      -- toml
      "taplo",
      -- yaml
      "yamlls",
      -- json
      "jsonls",
      -- markdown
      "marksman",
    })
  end,
}

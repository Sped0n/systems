---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@param opts AstroLSPOpts
  opts = function(_, opts)
    opts.features.inlay_hints = true

    opts.config.lua_ls.settings.Lua.diagnostics = opts.config.lua_ls.settings.Lua.diagnostics or {}
    opts.config.lua_ls.settings.Lua.diagnostics.globals = { "vim", "require" }

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

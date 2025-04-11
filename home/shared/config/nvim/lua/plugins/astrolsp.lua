---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@param opts AstroLSPOpts
  opts = function(_, opts)
    opts.features.inlay_hints = true
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
      -- typescript
      "vtsls",
      "eslint",
      -- toml
      "taplo",
      -- yaml
      "yamlls",
      -- json
      "jsonls",
    })
  end,
}

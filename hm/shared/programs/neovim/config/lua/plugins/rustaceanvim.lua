---@type LazySpec
return {
  {
    "mrcjkb/rustaceanvim",
    optional = true,
    opts = function(_, opts)
      opts.dap = vim.fn.executable "lldb-dap" == 1
          and {
            adapter = {
              type = "executable",
              command = "lldb-dap",
              name = "lldb",
            },
            load_rust_types = true,
          }
        or nil
    end,
  },
}

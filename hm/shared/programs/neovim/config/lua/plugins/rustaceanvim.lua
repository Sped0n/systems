---@type LazySpec
return {
  {
    "mrcjkb/rustaceanvim",
    optional = true,
    opts = function(_, opts)
      local command = vim.fn.exepath "codelldb"
      local cfg = require "rustaceanvim.config"

      if command ~= "" then
        local this_os = vim.uv.os_uname().sysname
        local liblldb_path

        if this_os:find "Windows" then
          liblldb_path = vim.fn.exepath "liblldb.dll"
        elseif this_os == "Linux" then
          liblldb_path = vim.fn.exepath "liblldb.so"
        else
          liblldb_path = vim.fn.exepath "liblldb.dylib"
        end

        if liblldb_path ~= "" then
          opts.dap = { adapter = cfg.get_codelldb_adapter(command, liblldb_path), load_rust_types = true }
        else
          opts.dap = nil
        end
      else
        opts.dap = nil
      end
    end,
  },
}

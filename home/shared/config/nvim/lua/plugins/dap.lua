---@type LazySpec
return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require "dap"
      dap.adapters.lldb = {
        type = "executable",
        command = "lldb-dap",
        name = "lldb",
      }

      dap.configurations.zig = {
        {
          name = "Launch",
          type = "lldb",
          request = "launch",
          program = function() return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/zig-out/", "file") end,
          cwd = "${workspaceFolder}",
          stopOnEntry = true,
          args = {},
        },
        {
          name = "Attach to remote GDB server on localhost:3333",
          type = "lldb",
          request = "launch",
          program = function() return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/zig-out/", "file") end,
          processCreateCommands = {
            "gdb-remote localhost:3333",
          },
          cwd = "${workspaceFolder}",
          stopOnEntry = true,
          args = {},
        },
      }
    end,
  },
}

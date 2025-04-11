return {
  "mfussenegger/nvim-dap",
  config = function()
    local dap = require "dap"
    -- configure codelldb adapter
    dap.adapters.codelldb = {
      type = "server",
      port = "${port}",
      executable = {
        command = vim.fn.stdpath "data" .. "/mason/bin/codelldb",
        args = { "--port", "${port}" },
        cwd = vim.fn.getcwd(),
      },
    }

    -- setup a debugger config for zig projects
    dap.configurations.zig = {
      {
        name = "Launch",
        type = "codelldb",
        request = "launch",
        program = function() return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/zig-out/", "file") end,
        cwd = "${workspaceFolder}",
        stopOnEntry = true,
        args = {},
      },
      {
        name = "Launch with GDB remote target on localhost:3333",
        type = "codelldb",
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
}

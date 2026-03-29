return {
  {
    "Sped0n/ocx.nvim",

    -- name = "ocx.nvim",
    -- dir = "/Users/spedon/eden/nvim/ocx.nvim",

    -- name = "ocx.nvim",
    -- dir = "/home/spedon/eden/nvim/ocx.nvim",

    lazy = true,
    dependencies = {
      {
        "AstroNvim/astrocore",
        ---@param opts AstroCoreOpts
        opts = function(_, opts)
          local maps = assert(opts.mappings)
          local prefix = "<Leader>o"

          maps.n[prefix .. "5"] = {
            function() require("ocx").run "50" end,
            desc = "Run agent 50",
          }
          maps.n[prefix .. "9"] = {
            function() require("ocx").run "99" end,
            desc = "Run agent 99",
          }
          maps.n[prefix .. "c"] = {
            function() require("ocx").add_context() end,
            desc = "Add context",
          }
          maps.n[prefix .. "C"] = {
            function() require("ocx").add_context { select = true } end,
            desc = "Add context to specific session",
          }
          maps.n[prefix .. "t"] = {
            function() require("ocx").terminate() end,
            desc = "Terminate specific session",
          }
          maps.n[prefix .. "T"] = {
            function() require("ocx").terminate(nil, { force = true }) end,
            desc = "Terminate specific with force",
          }

          maps.v[prefix .. "5"] = {
            function() require("ocx").run "50" end,
            desc = "Run agent 50 on selection",
          }
          maps.v[prefix .. "9"] = {
            function() require("ocx").run "99" end,
            desc = "Run agent 99 on selection",
          }
          maps.v[prefix .. "c"] = {
            function() require("ocx").add_context() end,
            desc = "Add selection to context",
          }
          maps.v[prefix .. "C"] = {
            function() require("ocx").add_context { select = true } end,
            desc = "Add selection to specific session",
          }
        end,
      },
    },
    config = function() require("ocx").setup {} end,
  },
}

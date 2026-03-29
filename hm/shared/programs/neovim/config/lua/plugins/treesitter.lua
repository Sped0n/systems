return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if opts.ensure_installed ~= "all" then
        opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, {
          "dockerfile",
          "gn",
          "jsonc",
          "just",
          "kconfig",
          "nix",
          "regex",
          "sql",
          "ssh_config",
          "tmux",
        })
      end
    end,
  },
}

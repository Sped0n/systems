---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      auto_install = false,
      ensure_installed = {
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
      },
    },
  },
}

---@type LazySpec
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_by_name = {
            ".git",
            "node_modules",
          },
          always_show = { -- remains visible even if other settings would normally hide it
            ".envrc",
            "flake.nix",
            "flake.lock",
          },
        },
      },
    },
  },
}

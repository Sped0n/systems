-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- theme
  { import = "astrocommunity.colorscheme.kanagawa-nvim" },
  -- editor
  { import = "astrocommunity.editing-support.conform-nvim" },
  { import = "astrocommunity.git.git-blame-nvim" },
  { import = "astrocommunity.completion.minuet-ai-nvim" },
  { import = "astrocommunity.recipes.heirline-vscode-winbar" },
  -- languages
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.python-ruff" },
  { import = "astrocommunity.pack.cpp" },
  { import = "astrocommunity.pack.cmake" },
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.typescript" },
  { import = "astrocommunity.pack.go" },
  { import = "astrocommunity.pack.zig" },
  { import = "astrocommunity.pack.rust" },
  { import = "astrocommunity.pack.nix" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.prettier" },
  -- motion
  { import = "astrocommunity.motion.flash-nvim" },
  { import = "astrocommunity.motion.mini-surround" },
  -- search
  { import = "astrocommunity.search.grug-far-nvim" },
}

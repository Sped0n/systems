---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    options = {
      g = {
        gitblame_enabled = 0,
      },
    },
    mappings = {
      n = {
        ["<Leader>gB"] = { "<cmd>GitBlameToggle<cr>", desc = "Toggle Git Glame Virtual Text" },
      },
    },
  },
}

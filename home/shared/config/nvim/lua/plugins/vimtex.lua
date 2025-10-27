---@type LazySpec
return {
  {
    "lervag/vimtex",
    lazy = false,
    init = function()
      vim.g.vimtex_view_method = "zathura"
      vim.g.vimtex_view_zathura_use_synctex = 0
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft.tex = { "latexindent" }
      opts.formatters_by_ft.sty = { "latexindent" }
      opts.formatters_by_ft.cls = { "latexindent" }
      opts.formatters_by_ft.bib = { "bibtex-tidy" }
    end,
  },
}

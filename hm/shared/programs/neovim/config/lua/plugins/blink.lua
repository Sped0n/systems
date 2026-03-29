---@type LazySpec
return {
  "saghen/blink.cmp",
  opts = {
    sources = {
      providers = {
        buffer = {
          opts = {
            get_bufnrs = function()
              return vim.tbl_filter(function(bufnr) return vim.bo[bufnr].buftype == "" end, vim.api.nvim_list_bufs())
            end,
          },
        },
      },
    },
  },
}

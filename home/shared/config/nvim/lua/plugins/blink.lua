---@type LazySpec
return {
  "saghen/blink.cmp",
  opts = {
    sources = {
      providers = {
        buffer = {
          opts = {
            get_bufnrs = function()
              -- 1. Get info for all "normal" buffers.
              -- This is more efficient than filtering and then getting info for each one.
              -- It returns a list of tables, each with info like 'bufnr', 'lastused', etc.
              local bufinfos = vim.fn.getbufinfo { buftype = "normal" }

              -- 2. Sort the buffers by most recently used.
              -- The 'lastused' field is a timestamp; a higher value means it was used more recently.
              -- We sort in descending order to put the most recent buffers first.
              table.sort(bufinfos, function(a, b) return a.lastused > b.lastused end)

              -- 3. Extract the buffer numbers from the sorted list, limiting to a max of 5.
              local mru_bufs = {}
              for i = 1, math.min(5, #bufinfos) do
                table.insert(mru_bufs, bufinfos[i].bufnr)
              end

              return mru_bufs
            end,
          },
        },
      },
    },
  },
}

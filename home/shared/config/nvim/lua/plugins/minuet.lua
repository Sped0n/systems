---@type LazySpec
return {
  {
    "milanglacier/minuet-ai.nvim",
    opts = {
      provider = "openai_fim_compatible",
      request_timeout = 5.0,
      provider_options = {
        openai_fim_compatible = {
          api_key = "OPENAI_API_KEY",
          name = "deepseek",
          optional = {
            max_tokens = 256,
            top_p = 0.9,
          },
        },
      },
    },
  },

  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<C-;>"] = require("minuet").make_blink_map(),
      },
      sources = {
        providers = {
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            transform_items = function(_, items)
              for _, item in ipairs(items) do
                item.kind_icon = ""
                item.kind_name = "Minuet"
              end
              return items
            end,
            async = true,
            timeout_ms = 5000,
            score_offset = 8,
          },
        },
      },
      completion = { trigger = { prefetch_on_insert = false } },
    },
  },

  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = {
      icons = {
        MinuetLoading = "",
        MinuetDone = "✓",
      },
    },
  },

  {
    "rebelot/heirline.nvim",
    opts = function(_, opts)
      local status = require "astroui.status"

      local minuet_status = {
        active = false,
        message = "",
        icon = "MinuetLoading",
      }

      local clear_timer = vim.uv.new_timer()

      local minuet_augroup = vim.api.nvim_create_augroup("MinuetHeirline", { clear = true })

      vim.api.nvim_create_autocmd("User", {
        group = minuet_augroup,
        pattern = "MinuetRequestStarted",
        callback = function()
          if clear_timer then clear_timer:stop() end
          minuet_status.active = true
          minuet_status.message = " Thinking..."
          minuet_status.icon = "MinuetLoading"
          vim.cmd.redrawstatus()
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = minuet_augroup,
        pattern = "MinuetRequestFinished",
        callback = function()
          minuet_status.active = true
          minuet_status.message = "Done"
          minuet_status.icon = "MinuetDone"
          vim.cmd.redrawstatus()

          if clear_timer then
            clear_timer:start(
              3000,
              0,
              vim.schedule_wrap(function()
                minuet_status.active = false
                vim.cmd.redrawstatus()
              end)
            )
          end
        end,
      })

      local minuet_component = status.component.builder {
        condition = function() return minuet_status.active end,
        provider = function()
          return status.utils.stylize(minuet_status.message, {
            icon = { kind = minuet_status.icon, padding = { right = 1 } },
          })
        end,
        hl = function()
          if minuet_status.icon == "MinuetDone" then return require("astroui").get_hlgroup "GitSignsAdd" end
        end,
      }

      table.insert(opts.statusline, 9, minuet_component)

      return opts
    end,
  },
}

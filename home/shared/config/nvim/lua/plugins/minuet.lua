---@type LazySpec
return {
  {
    "milanglacier/minuet-ai.nvim",
    opts = {
      provider = "openai_fim_compatible",
      request_timeout = 3.0,
      provider_options = {
        openai_fim_compatible = {
          api_key = "OPENAI_API_KEY",
          end_point = "https://openrouter.ai/api/v1/completions",
          model = "mistralai/codestral-2501",
          name = "Openrouter",
          optional = {
            max_tokens = 256,
            top_p = 0.9,
            provider = {
              sort = "throughput",
            },
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
                item.kind_icon = "m"
                item.kind_name = "Minuet"
              end
              return items
            end,
            async = true,
            timeout_ms = 3000,
            score_offset = 8,
          },
        },
      },
      completion = { trigger = { prefetch_on_insert = false } },
    },
  },

  {
    "rebelot/heirline.nvim",
    opts = function(_, opts)
      local minuet_animation = {
        active = false,
        timer = nil,
        frames = { "[  m]", "[ m ]", "[m  ]" },
        frame_index = 1,
        interval = 200,
      }

      local minuet_augroup = vim.api.nvim_create_augroup("MinuetHeirlineAnimation", { clear = true })

      vim.api.nvim_create_autocmd("User", {
        group = minuet_augroup,
        pattern = "MinuetRequestStarted",
        callback = function()
          if minuet_animation.timer and not minuet_animation.timer:is_closing() then
            minuet_animation.timer:stop()
            minuet_animation.timer:close()
          end

          minuet_animation.active = true
          minuet_animation.frame_index = 1

          minuet_animation.timer = vim.uv.new_timer()
          minuet_animation.timer:start(
            0,
            minuet_animation.interval,
            vim.schedule_wrap(function()
              if not minuet_animation.active then return end
              minuet_animation.frame_index = (minuet_animation.frame_index % #minuet_animation.frames) + 1
              vim.cmd.redrawstatus()
            end)
          )
          vim.cmd.redrawstatus()
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = minuet_augroup,
        pattern = "MinuetRequestFinished",
        callback = function()
          minuet_animation.active = false
          if minuet_animation.timer and not minuet_animation.timer:is_closing() then
            minuet_animation.timer:stop()
            minuet_animation.timer:close()
            minuet_animation.timer = nil
          end
          vim.cmd.redrawstatus()
        end,
      })

      local minuet_component = {
        condition = function() return minuet_animation.active end,
        provider = function() return minuet_animation.frames[minuet_animation.frame_index] end,
      }

      table.insert(opts.statusline, 9, minuet_component)

      return opts
    end,
  },
}

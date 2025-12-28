-- ┌──────────────────────┐
-- │ Avante (AI Assistant)│
-- └──────────────────────┘
--
-- This file configures Avante.nvim for AI-assisted coding with Copilot/Claude.
-- Avante provides chat-based code generation and editing capabilities.
--
-- Usage:
-- - <leader>aa: Ask Avante a question
-- - <leader>ae: Edit code with Avante
-- - <leader>at: Toggle Avante window
--
-- See 'plugin/20_keymaps.lua' for all Avante keybindings.

local later = MiniDeps.later

later(function()
  -- Add dependencies first (before avante.nvim)
  MiniDeps.add('nvim-lua/plenary.nvim')
  MiniDeps.add('MunifTanjim/nui.nvim')
  MiniDeps.add('HakonHarnes/img-clip.nvim')
  MiniDeps.add('MeanderingProgrammer/render-markdown.nvim')
  MiniDeps.add('zbirenbaum/copilot.lua')

  -- Add avante.nvim last so dependencies are loaded
  MiniDeps.add({
    source = 'yetone/avante.nvim',
    -- Build binary components after checkout/update
    hooks = {
      post_checkout = function()
        vim.cmd('!make BUILD_FROM_SOURCE=true')
      end
    },
  })

  -- Wait for next event loop to ensure plugins are loaded
  vim.schedule(function()
    -- Configure render-markdown for Avante buffers ===========================
    local ok_render, render_markdown = pcall(require, 'render-markdown')
    if ok_render then
      render_markdown.setup({
        file_types = { 'markdown', 'Avante' },
      })
    end

    -- Configure img-clip for image pasting ===================================
    local ok_img, img_clip = pcall(require, 'img-clip')
    if ok_img then
      img_clip.setup({
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = { insert_mode = true },
        },
      })
    end

    -- Setup Avante ===========================================================
    local ok_avante, avante = pcall(require, 'avante')
    if not ok_avante then
      vim.notify('Avante.nvim not loaded. Run :DepsUpdate to install it.', vim.log.levels.WARN)
      return
    end

    avante.setup({
      provider = 'copilot',
      auto_suggestions_provider = 'copilot',
      providers = {
        copilot = {
          model = 'claude-sonnet-3.5',
        },
      },
      behaviour = {
        auto_suggestions = true,
        auto_set_highlight_group = true,
        auto_set_keymaps = true,
        auto_apply_diff_after_generation = false,
      },
    })
  end)
end)

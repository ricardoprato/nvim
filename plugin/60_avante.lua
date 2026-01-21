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

local later, add = MiniDeps.later, MiniDeps.add

later(function()
  -- Add dependencies first (before avante.nvim)
  add('HakonHarnes/img-clip.nvim')
  add('MeanderingProgrammer/render-markdown.nvim')
  add('zbirenbaum/copilot.lua')

  -- Add avante.nvim last so dependencies are loaded
  add({
    source = 'yetone/avante.nvim',
    depends = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
    },
    -- Build binary components after checkout/update
    hooks = { post_checkout = function() vim.cmd('make') end }
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
      provider = 'claude-code',
      behaviour = {
        auto_suggestions = false,
        auto_set_highlight_group = true,
        auto_set_keymaps = true,
        enable_cursor_planning_mode = true,
        enable_claude_text_editor_tool_mode = true,
        enable_fastapply = true,
      },
    })

    -- Workaround for LSP detach error in Avante buffers
    -- Prevents crash when Avante tries to detach LSP from already-cleaned buffers
    -- This fixes the "attempt to index local 'buf_state' (a nil value)" error
    local original_buf_detach = vim.lsp.buf_detach_client
    vim.lsp.buf_detach_client = function(bufnr, client_id)
      -- Check if buffer still exists and is valid
      if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      -- Check if LSP client is still attached
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      local is_attached = false
      for _, client in ipairs(clients) do
        if client.id == client_id then
          is_attached = true
          break
        end
      end
      -- Only detach if client is actually attached
      if is_attached then
        pcall(original_buf_detach, bufnr, client_id)
      end
    end
  end)
end)
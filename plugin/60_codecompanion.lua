-- ┌────────────────────────────────┐
-- │ CodeCompanion (AI Assistant)  │
-- └────────────────────────────────┘
--
-- This file configures codecompanion.nvim for AI-assisted coding with Claude Code.
-- CodeCompanion provides conversational chat with persistent context, slash commands
-- for injecting files/buffers/symbols, and agentic tools with diff preview.
--
-- Usage:
-- - <Leader>aa: Open/focus CodeCompanion chat
-- - <Leader>ae: Inline edit with CodeCompanion
-- - <Leader>at: Toggle CodeCompanion chat
-- - <Leader>ap: Open actions palette
--
-- Slash commands inside chat:
-- - /file   - Add any file from the workspace
-- - /buffer - Add current buffer content
-- - /symbols - Add LSP symbols from current file
-- - /fetch  - Fetch content from a URL
-- - /terminal - Add terminal output
--
-- See 'plugin/20_keymaps.lua' for all CodeCompanion keybindings.

local later, add = MiniDeps.later, MiniDeps.add

later(function()
  add('MeanderingProgrammer/render-markdown.nvim')

  add({
    source = 'olimorris/codecompanion.nvim',
    depends = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
  })

  -- render-markdown for chat buffer formatting
  local ok_render, render_markdown = pcall(require, 'render-markdown')
  if ok_render then
    render_markdown.setup({
      file_types = { 'markdown', 'codecompanion' },
    })
  end

  local ok_cc, codecompanion = pcall(require, 'codecompanion')
  if not ok_cc then
    vim.notify('codecompanion.nvim not loaded. Run :DepsUpdate to install it.', vim.log.levels.WARN)
    return
  end

  codecompanion.setup({
    adapters = {
      acp = {
        claude_code = function()
          return require('codecompanion.adapters').extend('claude_code', {
          env = {
            CLAUDE_CODE_OAUTH_TOKEN = 'cmd:cat ~/.config/claude/oauth_token',
          },
        })
        end,
      },
    },
    strategies = {
      chat = { adapter = 'claude_code' },
      inline = { adapter = 'claude_code' },
    },
    display = {
      diff = {
        enabled = true,
        provider = 'mini_diff',
      },
    },
  })
end)

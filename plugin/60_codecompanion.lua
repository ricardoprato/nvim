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

-- Pre-read OAuth token asynchronously so it's cached before the first chat.
-- This avoids a synchronous shell call (`cmd:cat ...`) blocking Neovim when
-- the adapter initialises.
local _cached_token = nil

vim.defer_fn(function()
  local token_path = vim.fn.expand('~/.config/claude/oauth_token')
  vim.uv.fs_open(token_path, 'r', 438, function(err, fd)
    if err or not fd then return end
    vim.uv.fs_fstat(fd, function(err2, stat)
      if err2 or not stat then
        vim.uv.fs_close(fd)
        return
      end
      vim.uv.fs_read(fd, stat.size, 0, function(err3, data)
        vim.uv.fs_close(fd)
        if not err3 and data then
          _cached_token = vim.trim(data)
        end
      end)
    end)
  end)
end, 0)

later(function()
  add('MeanderingProgrammer/render-markdown.nvim')

  add({
    source = 'olimorris/codecompanion.nvim',
    depends = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
  })

  add('ravitemer/codecompanion-history.nvim')
  add('zbirenbaum/copilot.lua')
  require('copilot').setup({
    suggestion = { enabled = false },
    panel = { enabled = false },
  })

  add({
    source = 'HakonHarnes/img-clip.nvim',
    hooks = {
      post_checkout = function() vim.cmd('TSUpdate') end,
    },
  })

  require('img-clip').setup({
    default = {
      embed_image_as_base64 = false,
      prompt_for_file_name = false,
      drag_and_drop = { insert_mode = true },
    },
    filetypes = {
      codecompanion = {
        url_encode_path = true,
        template = '![Image]($FILE_PATH)',
        use_absolute_path = true,
      },
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
              -- Use the pre-cached token (async read) with a synchronous fallback
              CLAUDE_CODE_OAUTH_TOKEN = function()
                if _cached_token then return _cached_token end
                -- Fallback: synchronous read (only on cold start race condition)
                local path = vim.fn.expand('~/.config/claude/oauth_token')
                local f = io.open(path, 'r')
                if f then
                  local data = f:read('*a')
                  f:close()
                  _cached_token = vim.trim(data)
                  return _cached_token
                end
                return ''
              end,
            },
            defaults = {
              model = 'opus',
              timeout = 120000,
            },
          })
        end,
      },
    },
    interactions = {
      background = {
        adapter = { name = 'copilot', model = 'gpt-4.1' },
        chat = {
          callbacks = {
            ['on_ready'] = { enabled = true },
          },
        },
      },
      chat = { adapter = 'claude_code' },
      inline = { adapter = 'claude_code' },
    },
    extensions = {
      history = {
        enabled = true,
        opts = {
          auto_save = true,
          auto_generate_title = true,
          continue_last_chat = false,
          expiration_days = 0,
          picker = 'default',
          title_generation_opts = {
            adapter = 'copilot',
            model = 'gpt-4.1',
          },
        },
      },
    },
    display = {
      chat = {
        show_header_separator = false, -- for render-markdown compatibility
        show_token_count = true,
        auto_scroll = true
      },
      diff = {
        enabled = true,
        provider = 'mini_diff',
      },
    },
  })
end)

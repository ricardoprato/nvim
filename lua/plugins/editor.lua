return {
  -- Obsidian
  {
    'obsidian-nvim/obsidian.nvim',
    event = {
      'BufReadPre ' .. vim.fn.expand('~') .. '/obsidian/**.md',
      'BufNewFile ' .. vim.fn.expand('~') .. '/obsidian/**.md',
    },
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      workspaces = { { name = 'personal', path = '~/obsidian' } },
      legacy_commands = false,
    },
  },

  -- Render Markdown
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    opts = { file_types = { 'markdown' } },
  },

  -- Diffview
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose' },
    opts = { use_icons = true },
  },

  -- Grug-far (search & replace)
  {
    'MagicDuck/grug-far.nvim',
    cmd = 'GrugFar',
    opts = {},
  },

  -- vim-sleuth (auto detect indent)
  { 'tpope/vim-sleuth', event = { 'BufReadPost', 'BufNewFile' } },

  -- Kulala (HTTP client)
  {
    'mistweaverco/kulala.nvim',
    ft = { 'http', 'rest' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('kulala').setup({
        display_mode = 'float',
        split_direction = 'vertical',
        default_formatters = {
          json = { 'jq', '-r' },
          xml = { 'xmllint', '--format', '-' },
          html = { 'xmllint', '--format', '--html', '-' },
        },
        icons = {
          inlay = { loading = '⏳', done = '✅', error = '❌' },
        },
        additional_curl_options = {},
      })

      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'http', 'rest' },
        callback = function(ev)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = 'Kulala: ' .. desc })
          end
          map('n', '<CR>', require('kulala').run, 'Run request')
          map('n', '<leader>rr', require('kulala').run, 'Run request')
          map('n', '[r', require('kulala').jump_prev, 'Previous request')
          map('n', ']r', require('kulala').jump_next, 'Next request')
          map('n', '<leader>ri', require('kulala').inspect, 'Inspect request')
          map('n', '<leader>rt', require('kulala').toggle_view, 'Toggle headers/body')
          map('n', '<leader>rc', require('kulala').copy, 'Copy as cURL')
          map('n', '<leader>rp', require('kulala').from_curl, 'Paste from cURL')
          map('n', '<leader>ry', require('kulala').copy_response, 'Copy response')
          map('n', '<leader>re', require('kulala').set_selected_env, 'Select environment')
        end,
      })
    end,
  },
}

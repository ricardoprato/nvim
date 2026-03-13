return {
  'saghen/blink.cmp',
  event = { 'InsertEnter', 'CmdlineEnter' },
  build = 'cargo build --release',
  dependencies = { 'rafamadriz/friendly-snippets' },
  config = function()
    require('blink.cmp').setup({
      snippets = { preset = 'mini_snippets' },
    })
    vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })
  end,
}

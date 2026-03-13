return {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      vim.lsp.enable({
        'lua_ls', 'pyright', 'odoo_lsp', 'ts_ls', 'eslint',
        'denols', 'jsonls', 'yamlls', 'lemminx', 'astro',
      })
    end,
  },
  { 'b0o/SchemaStore.nvim', lazy = true },
  {
    'mason-org/mason.nvim',
    cmd = 'Mason',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = {
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
    },
    config = function()
      require('mason').setup({ PATH = 'prepend' })
      require('mason-lspconfig').setup({
        ensure_installed = {
          'lua_ls', 'pyright', 'ts_ls', 'eslint',
          'denols', 'jsonls', 'yamlls', 'lemminx', 'astro',
        },
        automatic_installation = true,
      })
      require('mason-tool-installer').setup({
        ensure_installed = { 'stylua', 'black', 'isort', 'prettier' },
        auto_update = true,
      })
    end,
  },
}

return {
  'stevearc/conform.nvim',
  event = 'BufWritePost',
  cmd = 'ConformInfo',
  config = function()
    require('conform').setup({
      notify_on_error = false,
      format_after_save = function(bufnr)
        if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
          return
        end
        return { timeout_ms = 2000, lsp_format = 'never' }
      end,
      formatters = {
        black = { prepend_args = { '--fast' } },
      },
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'isort', 'black' },
        javascript = { 'prettier', 'deno_fmt', stop_after_first = true },
        typescript = { 'prettier', 'deno_fmt', stop_after_first = true },
        javascriptreact = { 'prettier', 'deno_fmt', stop_after_first = true },
        typescriptreact = { 'prettier', 'deno_fmt', stop_after_first = true },
        json = { 'prettier', 'deno_fmt', stop_after_first = true },
        yaml = { 'prettier' },
        xml = { 'xmlformatter' },
      },
    })
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}

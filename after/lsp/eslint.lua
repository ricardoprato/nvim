-- ESLint LSP configuration for React Native/Expo projects
-- Provides linting and auto-fix on save

return {
  -- Only enable in projects with eslint config (not Deno projects)
  root_markers = {
    '.eslintrc',
    '.eslintrc.js',
    '.eslintrc.cjs',
    '.eslintrc.json',
    '.eslintrc.yaml',
    '.eslintrc.yml',
    'eslint.config.js',
    'eslint.config.mjs',
    'eslint.config.cjs',
  },
  settings = {
    -- Flat config support (ESLint 9+)
    experimental = {
      useFlatConfig = true,
    },
    -- Working directories for monorepos
    workingDirectories = { mode = 'auto' },
    -- Code action settings
    codeAction = {
      disableRuleComment = {
        enable = true,
        location = 'separateLine',
      },
      showDocumentation = {
        enable = true,
      },
    },
  },
  -- Auto-fix on save
  on_attach = function(client, bufnr)
    -- Create autocmd to fix on save
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = bufnr,
      callback = function()
        -- Only run if ESLint is attached and not disabled
        if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
          return
        end
        vim.lsp.buf.code_action({
          context = { only = { 'source.fixAll.eslint' } },
          apply = true,
        })
      end,
    })
  end,
}

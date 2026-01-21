-- TypeScript/JavaScript LSP configuration
-- Enhanced for React Native/Expo development

return {
  -- Avoid conflict with Deno projects
  root_markers = {
    'tsconfig.json',
    'jsconfig.json',
    'package.json',
  },
  settings = {
    typescript = {
      -- Inlay hints for better code understanding
      inlayHints = {
        includeInlayParameterNameHints = 'all',
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
      -- Suggestions and imports
      suggest = {
        autoImports = true,
        completeFunctionCalls = true,
        includeCompletionsForModuleExports = true,
        includeAutomaticOptionalChainCompletions = true,
      },
      -- Update imports on file move/rename
      updateImportsOnFileMove = {
        enabled = 'always',
      },
      -- Preferences
      preferences = {
        importModuleSpecifier = 'relative',
        quoteStyle = 'single',
      },
    },
    javascript = {
      -- Same inlay hints for JavaScript
      inlayHints = {
        includeInlayParameterNameHints = 'all',
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
      suggest = {
        autoImports = true,
        completeFunctionCalls = true,
        includeCompletionsForModuleExports = true,
        includeAutomaticOptionalChainCompletions = true,
      },
      updateImportsOnFileMove = {
        enabled = 'always',
      },
      preferences = {
        importModuleSpecifier = 'relative',
        quoteStyle = 'single',
      },
    },
    -- Completions
    completions = {
      completeFunctionCalls = true,
    },
  },
  on_attach = function(client, bufnr)
    -- Enable inlay hints by default (Neovim 0.10+)
    if vim.lsp.inlay_hint then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end
  end,
}

-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- This file contains installation and configuration of plugins outside of MINI.
-- They significantly improve user experience in a way not yet possible with MINI.
-- These are mostly plugins that provide programming language specific behavior.
--
-- Use this file to install and configure other such plugins.

-- Make concise helpers for installing/adding plugins in two stages
local add, later, now = MiniDeps.add, MiniDeps.later, MiniDeps.now
local now_if_args = _G.Config.now_if_args

-- Tree-sitter ================================================================

-- Tree-sitter is a tool for fast incremental parsing. It converts text into
-- a hierarchical structure (called tree) that can be used to implement advanced
-- and/or more precise actions: syntax highlighting, textobjects, indent, etc.
--
-- Tree-sitter support is built into Neovim (see `:h treesitter`). However, it
-- requires two extra pieces that don't come with Neovim directly:
-- - Language parsers: programs that convert text into trees. Some are built-in
--   (like for Lua), 'nvim-treesitter' provides many others.
--   NOTE: It requires third party software to build and install parsers.
--   See the link for more info in "Requirements" section of the MiniMax README.
-- - Query files: definitions of how to extract information from trees in
--   a useful manner (see `:h treesitter-query`). 'nvim-treesitter' also provides
--   these, while 'nvim-treesitter-textobjects' provides the ones for Neovim
--   textobjects (see `:h text-objects`, `:h MiniAi.gen_spec.treesitter()`).
--
-- Add these plugins now if file (and not 'mini.starter') is shown after startup.
now_if_args(function()
  add({
    source = 'nvim-treesitter/nvim-treesitter',
    -- Use `main` branch since `master` branch is frozen, yet still default
    checkout = 'main',
    -- Update tree-sitter parser after plugin is updated
    hooks = { post_checkout = function() vim.cmd('TSUpdate') end },
  })
  add({
    source = 'nvim-treesitter/nvim-treesitter-textobjects',
    -- Same logic as for 'nvim-treesitter'
    checkout = 'main',
  })

  -- Define languages which will have parsers installed and auto enabled
  local languages = {
    -- Default
    'lua', 'vimdoc', 'markdown', 'markdown_inline',
    -- Odoo stack
    'python', 'xml', 'html', 'css',
    -- JavaScript frameworks
    'javascript', 'typescript', 'tsx', 'jsx',
    -- Additional
    'bash', 'json', 'yaml', 'toml', 'dockerfile',
    'gitcommit', 'diff', 'query',
  }
  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then require('nvim-treesitter').install(to_install) end

  -- Enable tree-sitter after opening a file for a target language
  local filetypes = {}
  for _, lang in ipairs(languages) do
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      table.insert(filetypes, ft)
    end
  end
  local ts_start = function(ev)
    -- Only start treesitter if parser is available
    local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
    if lang and #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) > 0 then
      pcall(vim.treesitter.start, ev.buf)
    end
  end
  _G.Config.new_autocmd('FileType', filetypes, ts_start, 'Start tree-sitter')
end)

-- Language servers ===========================================================

-- Language Server Protocol (LSP) is a set of conventions that power creation of
-- language specific tools. It requires two parts:
-- - Server - program that performs language specific computations.
-- - Client - program that asks server for computations and shows results.
--
-- Here Neovim itself is a client (see `:h vim.lsp`). Language servers need to
-- be installed separately based on your OS, CLI tools, and preferences.
-- See note about 'mason.nvim' at the bottom of the file.
--
-- Neovim's team collects commonly used configurations for most language servers
-- inside 'neovim/nvim-lspconfig' plugin.
--
-- Add it now if file (and not 'mini.starter') is shown after startup.
now_if_args(function()
  add('neovim/nvim-lspconfig')

  -- Use `:h vim.lsp.enable()` to automatically enable language server based on
  -- the rules provided by 'nvim-lspconfig'.
  -- Use `:h vim.lsp.config()` or 'after/lsp/' directory to configure servers.
  vim.lsp.enable({
    'lua_ls',   -- Lua
    'pyright',  -- Python
    'odoo_lsp', -- Odoo (Python/XML/JS)
    'ts_ls',    -- TypeScript/JavaScript
    'denols',   -- Deno
    'jsonls',   -- JSON
    'yamlls',   -- YAML
    'lemminx',  -- XML (for Odoo)
  })
end)
-- SchemaStore ================================================================

-- SchemaStore provides JSON/YAML schemas for better validation and completion
later(function() add('b0o/SchemaStore.nvim') end)

-- Formatting =================================================================

-- Programs dedicated to text formatting (a.k.a. formatters) are very useful.
-- Neovim has built-in tools for text formatting (see `:h gq` and `:h 'formatprg'`).
-- They can be used to configure external programs, but it might become tedious.
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup.
later(function()
  add('stevearc/conform.nvim')

  -- See also:
  -- - `:h Conform`
  -- - `:h conform-options`
  -- - `:h conform-formatters`
  require('conform').setup({
    notify_on_error = false,
    format_on_save = function(bufnr)
      -- Don't auto-format if disabled
      if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
        return
      end

      return {
        timeout_ms = 2000,
        lsp_format = 'fallback',
      }
    end,
    formatters = {
      black = {
        prepend_args = { '--fast' },
      },
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
      xml = {}, -- Use LSP formatting for XML
    },
  })

  -- Set formatexpr for gq command
  vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
end)

-- Snippets ===================================================================

-- Although 'mini.snippets' provides functionality to manage snippet files, it
-- deliberately doesn't come with those.
--
-- The 'rafamadriz/friendly-snippets' is currently the largest collection of
-- snippet files. They are organized in 'snippets/' directory (mostly) per language.
-- 'mini.snippets' is designed to work with it as seamlessly as possible.
-- See `:h MiniSnippets.gen_loader.from_lang()`.
later(function() add('rafamadriz/friendly-snippets') end)

-- Honorable mentions =========================================================

-- 'mason-org/mason.nvim' (a.k.a. "Mason") is a great tool (package manager) for
-- installing external language servers, formatters, and linters. It provides
-- a unified interface for installing, updating, and deleting such programs.
--
-- The caveat is that these programs will be set up to be mostly used inside Neovim.
-- If you need them to work elsewhere, consider using other package managers.
--
-- You can use it like so:
later(function()
  add('mason-org/mason.nvim')
  add('mason-org/mason-lspconfig.nvim')
  add('WhoIsSethDaniel/mason-tool-installer.nvim')

  require('mason').setup()

  -- Auto-install LSP servers
  require('mason-lspconfig').setup({
    ensure_installed = {
      'lua_ls',
      'pyright',
      'ts_ls',
      'denols',
      'jsonls',
      'yamlls',
      'lemminx', -- XML LSP for Odoo
    },
  })

  -- Auto-install formatters and other tools
  require('mason-tool-installer').setup({
    ensure_installed = {
      -- Formatters
      'stylua', 'black', 'isort', 'prettier',
    },
    auto_update = true,
  })
end)

-- Beautiful, usable, well maintained color schemes outside of 'mini.nvim' and
-- have full support of its highlight groups. Use if you don't like 'miniwinter'
-- enabled in 'plugin/30_mini.lua' or other suggested 'mini.hues' based ones.

now(function()
  add({ source = "catppuccin/nvim", name = "catppuccin" })
  require("catppuccin").setup({
    flavour = "auto", -- latte, frappe, macchiato, mocha
    background = {    -- :h background
      light = "latte",
      dark = "mocha",
    },
    dim_inactive = {
      enabled = true,    -- dims the background color of inactive window
      shade = "dark",
      percentage = 0.15, -- percentage of the shade to apply to the inactive window
    },
    color_overrides = {},
    custom_highlights = {},
    default_integrations = true,
    integrations = {
      mason = true,
      mini = {
        enabled = true,
        indentscope_color = "mocha", -- catppuccin color (eg. `lavender`) Default: text
      },
      dap = true
    }
  })
  vim.cmd.colorscheme "catppuccin"
end)

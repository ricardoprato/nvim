-- ┌──────────────────────────┐
-- │ Built-in Neovim behavior │
-- └──────────────────────────┘
--
-- This file defines Neovim's built-in behavior. The goal is to improve overall
-- usability in a way that works best with MINI.
--
-- Here `vim.o.xxx = value` sets default value of option `xxx` to `value`.
-- See `:h 'xxx'` (replace `xxx` with actual option name).
--
-- Option values can be customized on per buffer or window basis.
-- See 'after/ftplugin/' for common example.

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- General ====================================================================
vim.g.mapleader   = ' '                              -- Use `<Space>` as <Leader> key

vim.o.mouse       = 'a'                              -- Enable mouse
vim.o.mousescroll = 'ver:25,hor:6'                   -- Customize mouse scroll
vim.o.switchbuf   = 'usetab,uselast'                 -- Use already opened buffers when switching
vim.o.autoread    = true                             -- Reload files changed outside Neovim
vim.o.undofile    = true                             -- Enable persistent undo
vim.o.undolevels  = 500                              -- Limit undo levels (default 1000)

vim.o.shada       = "'50,<30,s5,:500,/50,@50,h"      -- Limit ShaDa file (for startup)

-- Enable all filetype plugins and syntax (if not enabled, for better startup)
vim.cmd('filetype plugin indent on')
if vim.fn.exists('syntax_on') ~= 1 then vim.cmd('syntax enable') end

-- UI =========================================================================
vim.o.breakindent    = true                -- Indent wrapped lines to match line start
vim.o.breakindentopt = 'list:-1'           -- Add padding for lists (if 'wrap' is set)
vim.o.colorcolumn    = '+1'                -- Draw column on the right of maximum width
vim.o.cursorline     = true                -- Enable current line highlighting
vim.o.linebreak      = true                -- Wrap lines at 'breakat' (if 'wrap' is set)
vim.o.list           = true                -- Show helpful text indicators
vim.o.number         = true                -- Show line numbers
vim.o.pumheight      = 10                  -- Make popup menu smaller
vim.o.ruler          = false               -- Don't show cursor coordinates
vim.o.shortmess      = 'CFOSWaco'          -- Disable some built-in completion messages
vim.o.showmode       = false               -- Don't show mode in command line
vim.o.signcolumn     = 'yes'               -- Always show signcolumn (less flicker)
vim.o.splitbelow     = true                -- Horizontal splits will be below
vim.o.splitkeep      = 'screen'            -- Reduce scroll during window split
vim.o.splitright     = true                -- Vertical splits will be to the right
vim.o.winborder      = 'single'            -- Use border in floating windows
vim.o.wrap           = false               -- Don't visually wrap lines (toggle with \w)
vim.o.rnu            = true                -- Show the line number relative to the line with the cursor

vim.o.cursorlineopt  = 'screenline,number' -- Show cursor line per screen line
vim.o.synmaxcol      = 300                 -- No resaltar después de columna 300

-- Special UI symbols. More is set via 'mini.basics' later.
vim.o.fillchars      = 'eob: ,fold:╌'
vim.o.listchars      = 'extends:…,nbsp:␣,precedes:…,tab:> '

-- Folds (see `:h fold-commands`, `:h zM`, `:h zR`, `:h zA`, `:h zj`)
vim.o.foldlevel      = 10       -- Fold nothing by default; set to 0 or 1 to fold
vim.o.foldmethod     = 'indent' -- Fold based on indent level
vim.o.foldnestmax    = 10       -- Limit number of fold levels
vim.o.foldtext       = ''       -- Show text under fold with its highlighting

-- Editing ====================================================================
vim.o.autoindent     = true                  -- Use auto indent
vim.o.expandtab      = true                  -- Convert tabs to spaces
vim.o.formatoptions  = 'rqnl1j'              -- Improve comment editing
vim.o.ignorecase     = true                  -- Ignore case during search
vim.o.incsearch      = true                  -- Show search matches while typing
vim.o.infercase      = true                  -- Infer case in built-in completion
vim.o.shiftwidth     = 2                     -- Use this number of spaces for indentation
vim.o.smartcase      = true                  -- Respect case if search pattern has upper case
vim.o.smartindent    = true                  -- Make indenting smart
vim.o.spelloptions   = 'camel'               -- Treat camelCase word parts as separate words
vim.o.tabstop        = 2                     -- Show tab as this number of spaces
vim.o.virtualedit    = 'block'               -- Allow going past end of line in blockwise mode
vim.o.fileformat     = 'unix'                -- This gives the <EOL> of the current buffer

vim.o.iskeyword      = '@,48-57,_,192-255,-' -- Treat dash as `word` textobject part

-- Pattern for a start of numbered list (used in `gw`). This reads as
-- "Start of list item is: at least one special character (digit, -, +, *)
-- possibly followed by punctuation (. or `)`) followed by at least one space".
vim.o.formatlistpat  = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

-- Built-in completion
vim.o.complete       = '.,w,b,kspell'                  -- Use less sources
vim.o.completeopt    = 'menuone,noselect,fuzzy,nosort' -- Use custom behavior

-- Big files ==================================================================
-- Using Snacks.bigfile instead. Custom implementation commented out for reference
-- in case we need to restore the more aggressive version (pre-read swap/undo disable,
-- treesitter stop, diagnostics disable, etc.).

--[[ Custom bigfile implementation (more aggressive than Snacks):
local bigfile_threshold = 1.5 * 1024 * 1024 -- 1.5 MB
local bigfile_group = vim.api.nvim_create_augroup('bigfile', { clear = true })

vim.api.nvim_create_autocmd('BufReadPre', {
  group = bigfile_group,
  callback = function(args)
    local path = vim.api.nvim_buf_get_name(args.buf)
    if path == '' then return end
    local ok, stat = pcall(vim.uv.fs_stat, path)
    if not ok or not stat or stat.size < bigfile_threshold then return end
    vim.b[args.buf].bigfile = true
    vim.api.nvim_set_option_value('swapfile',  false, { buf = args.buf })
    vim.api.nvim_set_option_value('undofile',  false, { buf = args.buf })
    vim.api.nvim_set_option_value('undolevels', -1,   { buf = args.buf })
  end,
  desc = 'Mark big files and disable swap/undo before read',
})

vim.api.nvim_create_autocmd('BufReadPost', {
  group = bigfile_group,
  callback = function(args)
    if not vim.b[args.buf].bigfile then return end
    local function apply_win_opts(win)
      vim.api.nvim_set_option_value('foldmethod',  'manual', { win = win })
      vim.api.nvim_set_option_value('foldenable',  false,    { win = win })
      vim.api.nvim_set_option_value('cursorline',  false,    { win = win })
      vim.api.nvim_set_option_value('relativenumber', false, { win = win })
      vim.api.nvim_set_option_value('spell',       false,    { win = win })
      vim.api.nvim_set_option_value('signcolumn',  'no',     { win = win })
      vim.api.nvim_set_option_value('colorcolumn', '',       { win = win })
    end
    for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
      apply_win_opts(win)
    end
    vim.api.nvim_create_autocmd('BufWinEnter', {
      group = bigfile_group, buffer = args.buf,
      callback = function() apply_win_opts(vim.api.nvim_get_current_win()) end,
      desc = 'Apply bigfile win opts on new window',
    })
    vim.cmd('syntax clear')
    vim.bo[args.buf].syntax = ''
    vim.bo[args.buf].filetype = ''
    pcall(vim.treesitter.stop, args.buf)
    local mini_modules = { 'MiniTrailspace', 'MiniDiff', 'MiniHipatterns' }
    for _, mod in ipairs(mini_modules) do
      if _G[mod] then
        vim.b[args.buf]['mini' .. mod:sub(5):lower() .. '_disable'] = true
      end
    end
    vim.diagnostic.enable(false, { bufnr = args.buf })
    vim.b[args.buf].disable_autoformat = true
    vim.notify('Big file detected — heavy features disabled', vim.log.levels.INFO)
  end,
  desc = 'Disable heavy features after reading a big file',
})
--]]

-- Diagnostics ================================================================

-- Neovim has built-in support for showing diagnostic messages. This configures
-- a more conservative display while still being useful.
-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
local diagnostic_opts = {
  -- Show all diagnostics as underline (for their messages type `<Leader>ld`)
  underline = { severity = { min = 'HINT', max = 'ERROR' } },

  -- Show more details immediately for errors on the current line
  virtual_lines = false,
  virtual_text = {
    current_line = true,
    severity = { min = 'ERROR', max = 'ERROR' },
  },

  -- Don't update diagnostics when typing
  update_in_insert = false,
}

vim.diagnostic.config(diagnostic_opts)

-- stylua: ignore end

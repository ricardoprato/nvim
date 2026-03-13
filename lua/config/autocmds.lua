-- Autocommands extracted from plugin/10_options.lua and plugin/30_mini.lua
local augroup = vim.api.nvim_create_augroup('custom-config', { clear = true })

-- Don't auto-wrap comments and don't insert comment leader after hitting 'o'
vim.api.nvim_create_autocmd('FileType', {
  group = augroup,
  callback = function()
    vim.cmd('setlocal formatoptions-=c formatoptions-=o')
  end,
  desc = "Proper 'formatoptions'",
})

-- Reload buffers when Neovim regains focus or when switching buffers
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
  group = augroup,
  callback = function()
    if vim.o.buftype ~= '' then return end
    vim.cmd('checktime')
  end,
  desc = 'Check for external file changes',
})

-- Make q close help, man, quickfix, dap floats
vim.api.nvim_create_autocmd('BufWinEnter', {
  group = augroup,
  callback = function(args)
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = args.buf })
    if vim.tbl_contains({ 'help', 'nofile', 'quickfix' }, buftype) and vim.fn.maparg('q', 'n') == '' then
      vim.keymap.set('n', 'q', '<cmd>close<cr>', {
        desc = 'Close window',
        buffer = args.buf,
        silent = true,
        nowait = true,
      })
    end
  end,
  desc = 'Make q close help, man, quickfix, dap floats',
})

-- Reset Tailwind highlight cache on colorscheme change
vim.api.nvim_create_autocmd('ColorScheme', {
  group = augroup,
  pattern = '*',
  callback = function()
    require('utils.tailwind-colors').reset_cache()
  end,
  desc = 'Reset Tailwind highlight cache on colorscheme change',
})

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Global config table (used by utils and autocmds)
_G.Config = {}
_G.Config.initial_cwd = vim.fn.getcwd()

local augroup = vim.api.nvim_create_augroup('custom-config', {})
_G.Config.new_autocmd = function(event, pattern, callback, desc)
  vim.api.nvim_create_autocmd(event, {
    group = augroup, pattern = pattern, callback = callback, desc = desc,
  })
end

-- Load config files
require('config.options')
require('config.keymaps')
require('config.autocmds')

-- Setup lazy.nvim
require('lazy').setup({
  spec = { import = 'plugins' },
  install = { colorscheme = { 'catppuccin-mocha' } },
  checker = { enabled = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip', 'netrwPlugin', 'tarPlugin', 'tohtml', 'zipPlugin',
      },
    },
  },
})

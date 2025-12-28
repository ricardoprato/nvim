-- Python filetype settings with Odoo optimizations
--
-- This file is automatically loaded when opening Python files.
-- It applies Odoo-specific optimizations when working in Odoo projects.

local odoo = require('utils.odoo')

-- Check if in Odoo project and apply optimizations ===========================
if odoo.is_odoo_project() then
  odoo.setup_odoo_buffer()
  odoo.optimize_for_large_codebase()
end

-- Python-specific settings ===================================================

-- Set textwidth for Black formatter (default is 88)
vim.opt_local.textwidth = 88
vim.opt_local.colorcolumn = '+1'

-- Folding for Python
vim.opt_local.foldmethod = 'indent'
vim.opt_local.foldlevel = 2

-- Indentation (following PEP 8)
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4
vim.opt_local.expandtab = true

-- DAP keybindings hint (only show once per session)
if vim.fn.executable('debugpy') == 1 and not vim.g.dap_hint_shown then
  vim.defer_fn(function()
    vim.notify('DAP: F5=Continue, F9=Breakpoint, F10=StepOver, F11=StepInto', vim.log.levels.INFO)
    vim.g.dap_hint_shown = true
  end, 1000)
end

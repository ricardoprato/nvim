local M = {}

--- Detect if current project is an Odoo project
---@return boolean
function M.is_odoo_project()
  local root = require('utils.root').project_root()
  local markers = {
    root .. '/.odoo_lsp',
    root .. '/.odoo_lsp.json',
    root .. '/odoo-bin',
    root .. '/odoo.py',
  }

  for _, marker in ipairs(markers) do
    if vim.fn.filereadable(marker) == 1 then
      return true
    end
  end
  return false
end

--- Setup buffer-specific optimizations for Odoo files
function M.setup_odoo_buffer()
  -- Disable swap files for large XML files
  vim.bo.swapfile = false

  -- XML-specific folding for better navigation
  if vim.bo.filetype == 'xml' then
    vim.wo.foldmethod = 'indent'
    vim.wo.foldlevel = 1
  end
end

--- Optimize settings for large Odoo codebases
function M.optimize_for_large_codebase()
  if M.is_odoo_project() then
    vim.opt.updatetime = 500 -- Less frequent updates for better performance
    vim.g.matchparen_timeout = 20 -- Faster matchparen timeout
  end
end

return M

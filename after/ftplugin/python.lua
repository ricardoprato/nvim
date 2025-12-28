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

-- ┌─────────────────┐
-- │ Git-Flow Setup  │
-- └─────────────────┘
--
-- This file sets up the :GitFlow user command with autocompletion.
-- The actual git-flow wrapper logic is in lua/utils/git-flow.lua

-- Create :GitFlow command with autocompletion
vim.api.nvim_create_user_command('GitFlow', function(opts)
  require('utils.git-flow').command(opts)
end, {
  nargs = '*',
  complete = function(arg_lead, cmd_line, cursor_pos)
    return require('utils.git-flow').complete(arg_lead, cmd_line, cursor_pos)
  end,
  desc = 'Execute git-flow commands',
})

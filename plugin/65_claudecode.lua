-- ┌─────────────────────────────────────┐
-- │ Claude Code CLI (claudecode.nvim)  │
-- └─────────────────────────────────────┘
--
-- This file configures coder/claudecode.nvim for the Claude Code CLI terminal
-- experience inside Neovim. It implements the same WebSocket MCP protocol as
-- the VS Code extension, enabling agentic coding with file @-mentions, native
-- diff review, selection sending, and session management.
--
-- Usage:
-- - <Leader>aa: Toggle Claude Code terminal
-- - <Leader>af: Focus Claude Code terminal
-- - <Leader>as: Send visual selection to Claude
-- - <Leader>ai: Add file (@-mention) / Add selection (visual)
-- - <Leader>ad: Accept diff / <Leader>aD: Deny diff
-- - <Leader>ah: Session history picker
--
-- See 'plugin/20_keymaps.lua' for all Claude Code keybindings.

local later, add = MiniDeps.later, MiniDeps.add

later(function()
	add({ source = "coder/claudecode.nvim" })

	local ok, claudecode = pcall(require, "claudecode")
	if not ok then
		vim.notify("claudecode.nvim not loaded. Run :DepsUpdate to install it.", vim.log.levels.WARN)
		return
	end

	claudecode.setup()
end)

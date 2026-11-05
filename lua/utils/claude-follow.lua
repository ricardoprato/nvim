-- Follow Claude Code edits live. The PostToolUse hook in
-- ~/.claude/hooks/nvim-follow.sh calls open() over $NVIM after every
-- Edit/Write, so each touched file shows up in an editor window as Claude
-- writes it. Focus stays in the Claude terminal: the buffer swap happens
-- inside nvim_win_call, so typing in the prompt is never interrupted.

local M = {}

---@param win integer
---@return boolean
local function is_editor_window(win)
	local buf = vim.api.nvim_win_get_buf(win)
	return vim.api.nvim_win_get_config(win).relative == "" and vim.bo[buf].buftype == ""
end

-- Fallback when no file is open yet: a fresh session shows the snacks
-- dashboard (buftype nofile) next to Claude, and that is the obvious place to
-- land. Terminals and floats are never replaced.
---@param win integer
---@return boolean
local function is_replaceable_window(win)
	local buf = vim.api.nvim_win_get_buf(win)
	return vim.api.nvim_win_get_config(win).relative == "" and vim.bo[buf].buftype ~= "terminal"
end

-- Prefer the previous window: with Claude in a split, that is the code window
-- the user was last reading, so the file lands where their eyes already are.
---@return integer|nil
local function target_window()
	local prev = vim.fn.win_getid(vim.fn.winnr("#"))
	if prev ~= 0 and is_editor_window(prev) then
		return prev
	end
	local wins = vim.api.nvim_tabpage_list_wins(0)
	for _, win in ipairs(wins) do
		if is_editor_window(win) then
			return win
		end
	end
	for _, win in ipairs(wins) do
		if is_replaceable_window(win) then
			return win
		end
	end
end

---@param path string absolute path of the file Claude just wrote
function M.open(path)
	local buf = vim.fn.bufnr(path)
	if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
		-- autoread only fires on focus or cursor events, and focus is in the
		-- terminal, so an already-open buffer would keep showing stale text.
		vim.cmd.checktime(buf)
		if vim.fn.bufwinid(buf) ~= -1 then
			return
		end
	end

	local win = target_window()
	if not win then
		vim.notify("claude-follow: no editor window to show " .. path, vim.log.levels.WARN)
		return
	end
	vim.api.nvim_win_call(win, function()
		vim.cmd.edit(vim.fn.fnameescape(path))
	end)
end

return M

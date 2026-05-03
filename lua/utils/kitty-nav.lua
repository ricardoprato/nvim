local M = {}

local direction_map = {
	h = { wincmd = "h", kitty = "left" },
	j = { wincmd = "j", kitty = "bottom" },
	k = { wincmd = "k", kitty = "top" },
	l = { wincmd = "l", kitty = "right" },
}

function M.navigate(dir)
	local info = direction_map[dir]
	if not info then
		return
	end

	-- Pitfall 9 (MCLAUDE-11): do not navigate out of a floating window via
	-- wincmd or fall through to kitty pane. Inside a float, wincmd h/j/k/l is
	-- a no-op; without this guard, the kitty fallback fires and swaps the
	-- terminal pane underneath the user, losing nvim focus entirely.
	if vim.api.nvim_win_get_config(0).relative ~= "" then
		return
	end

	local cur_win = vim.api.nvim_get_current_win()
	vim.cmd("wincmd " .. dir)

	if vim.api.nvim_get_current_win() == cur_win then
		vim.fn.system({ "kitty", "@", "kitten", "kittens/navigate_kitty.py", info.kitty })
	end
end

return M

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

	local cur_win = vim.api.nvim_get_current_win()
	vim.cmd("wincmd " .. dir)

	if vim.api.nvim_get_current_win() == cur_win then
		-- Inside a float, wincmd h/j/k/l is a no-op. Without this guard the
		-- kitty fallback would fire and swap the terminal pane underneath the
		-- user, losing nvim focus entirely. The check is here (not before
		-- wincmd) so non-float panes inside snacks composites can still
		-- escape via wincmd.
		if vim.api.nvim_win_get_config(cur_win).relative ~= "" then
			return
		end
		vim.fn.system({ "kitty", "@", "kitten", "kittens/navigate_kitty.py", info.kitty })
	end
end

return M

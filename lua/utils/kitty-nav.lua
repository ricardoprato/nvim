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

	-- Floating windows (claudecode, lazygit, lazydocker, etc.) don't
	-- participate in wincmd's window graph, so navigation strands the user
	-- inside the float. Close it and continue the navigation from the
	-- underlying split; bufhidden=hide on these terminals keeps the buffer
	-- alive so toggling reopens with same state.
	if vim.api.nvim_win_get_config(cur_win).relative ~= "" then
		local has_normal_win = false
		for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if w ~= cur_win and vim.api.nvim_win_get_config(w).relative == "" then
				has_normal_win = true
				break
			end
		end
		if not has_normal_win then
			return
		end
		pcall(vim.api.nvim_win_close, cur_win, false)
		cur_win = vim.api.nvim_get_current_win()
	end

	vim.cmd("wincmd " .. dir)

	if vim.api.nvim_get_current_win() == cur_win then
		-- Still inside a float (close failed or close landed in another
		-- float — unusual). Don't fall through to kitty: it would swap the
		-- kitty pane underneath the user. Non-float panes inside snacks
		-- composites already escaped via wincmd above.
		if vim.api.nvim_win_get_config(cur_win).relative ~= "" then
			return
		end
		vim.fn.system({ "kitty", "@", "kitten", "kittens/navigate_kitty.py", info.kitty })
	end
end

return M

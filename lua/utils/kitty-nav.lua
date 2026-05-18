local M = {}

local direction_map = {
	h = { wincmd = "h", kitty = "left" },
	j = { wincmd = "j", kitty = "bottom" },
	k = { wincmd = "k", kitty = "top" },
	l = { wincmd = "l", kitty = "right" },
}

local dir_to_position = { h = "left", j = "bottom", k = "top", l = "right" }
local exit_dir_for_position = { left = "l", right = "h", top = "j", bottom = "k" }

local function active_pickers()
	local ok, picker = pcall(require, "snacks.picker")
	if not ok then
		return {}
	end
	return picker.get() or {}
end

local function picker_position(p)
	local layout = p.layout and p.layout.opts and p.layout.opts.layout
	return layout and layout.position or nil
end

local function find_picker_at(position)
	for _, p in ipairs(active_pickers()) do
		if picker_position(p) == position then
			return p
		end
	end
end

local function picker_owning_win(win)
	for _, p in ipairs(active_pickers()) do
		for _, w in pairs((p.layout and p.layout.wins) or {}) do
			if w.win == win then
				return p
			end
		end
	end
end

local function focus_first_normal_win()
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local cfg = vim.api.nvim_win_get_config(w)
		if cfg.relative == "" and cfg.focusable ~= false then
			vim.api.nvim_set_current_win(w)
			return true
		end
	end
	return false
end

-- Find a window (split OR float) whose viewport sits in `dir` relative to `from_win`.
-- Used to reach claudecode/snacks "sidebar" floats AND regular splits when leaving
-- a float (wincmd doesn't reach either from inside a float).
local function find_window_in_direction(dir, from_win, opts)
	opts = opts or {}
	local from = vim.api.nvim_win_get_position(from_win)
	local from_row, from_col = from[1], from[2]
	local from_h = vim.api.nvim_win_get_height(from_win)
	local from_w = vim.api.nvim_win_get_width(from_win)

	local best, best_score
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if w ~= from_win then
			local cfg = vim.api.nvim_win_get_config(w)
			if cfg.focusable ~= false and not cfg.external then
				local buf = vim.api.nvim_win_get_buf(w)
				local bt = vim.bo[buf].buftype
				local ft = vim.bo[buf].filetype
				-- Skip snacks picker floats (handled via pickers API).
				local skip = ft == "snacks_picker_list" or ft == "snacks_picker_input"
				-- Optional: only floats (used when caller already did wincmd).
				if opts.floats_only and cfg.relative == "" then
					skip = true
				end
				if not skip then
					local pos = vim.api.nvim_win_get_position(w)
					local row, col = pos[1], pos[2]
					local h = vim.api.nvim_win_get_height(w)
					local w_width = vim.api.nvim_win_get_width(w)
					local matches, dist = false, 0
					if dir == "l" and col >= from_col + from_w then
						matches, dist = true, col - (from_col + from_w)
					elseif dir == "h" and col + w_width <= from_col then
						matches, dist = true, from_col - (col + w_width)
					elseif dir == "j" and row >= from_row + from_h then
						matches, dist = true, row - (from_row + from_h)
					elseif dir == "k" and row + h <= from_row then
						matches, dist = true, from_row - (row + h)
					end
					if matches then
						-- Prefer terminal (claude/lazygit) over plain buffers.
						local score = dist - (bt == "terminal" and 1000 or 0)
						if not best_score or score < best_score then
							best, best_score = w, score
						end
					end
				end
			end
		end
	end
	return best
end

function M.navigate(dir)
	local info = direction_map[dir]
	if not info then
		return
	end

	local cur_win = vim.api.nvim_get_current_win()
	local is_float = vim.api.nvim_win_get_config(cur_win).relative ~= ""

	if is_float then
		-- Snacks pickers (e.g. explorer) are sidebar floats: route nav out of
		-- them into a normal window when direction leaves the picker.
		local picker = picker_owning_win(cur_win)
		local pos = picker and picker_position(picker)
		if pos and exit_dir_for_position[pos] == dir and focus_first_normal_win() then
			return
		end

		-- Find any window (split or float) in that direction — wincmd can't
		-- reach anything from inside a float.
		local target = find_window_in_direction(dir, cur_win)
		if target then
			vim.api.nvim_set_current_win(target)
			return
		end

		-- Truly modal floats with nothing in that direction: jump to kitty pane.
		vim.fn.system({ "kitty", "@", "kitten", "kittens/navigate_kitty.py", info.kitty })
		return
	end

	vim.cmd("wincmd " .. dir)

	if vim.api.nvim_get_current_win() == cur_win then
		-- wincmd no-op: try snacks picker on that side first.
		local picker = find_picker_at(dir_to_position[dir])
		if picker then
			picker:focus()
			return
		end
		-- Then look for editor-relative floats (claudecode sidebar, etc.).
		local target = find_window_in_direction(dir, cur_win, { floats_only = true })
		if target then
			vim.api.nvim_set_current_win(target)
			return
		end
		vim.fn.system({ "kitty", "@", "kitten", "kittens/navigate_kitty.py", info.kitty })
	end
end

return M

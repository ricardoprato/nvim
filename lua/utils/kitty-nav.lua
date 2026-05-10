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

		-- Modal floats (claudecode, lazygit, lazydocker): jump to kitty pane.
		vim.fn.system({ "kitty", "@", "kitten", "kittens/navigate_kitty.py", info.kitty })
		return
	end

	vim.cmd("wincmd " .. dir)

	if vim.api.nvim_get_current_win() == cur_win then
		-- wincmd no-op: try snacks picker on that side before kitty fallback.
		local picker = find_picker_at(dir_to_position[dir])
		if picker then
			picker:focus()
			return
		end
		vim.fn.system({ "kitty", "@", "kitten", "kittens/navigate_kitty.py", info.kitty })
	end
end

return M

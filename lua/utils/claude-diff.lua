-- ┌──────────────────────────────┐
-- │ Diffview → Claude at-mentions │
-- └──────────────────────────────┘
--
-- :ClaudeCodeSend cannot fire from most Diffview windows. claudecode.nvim builds
-- its at-mention from vim.api.nvim_buf_get_name() and hard-validates it
-- (init.lua _format_path_for_at_mention: `filereadable(path) == 0 and
-- isdirectory(path) == 0` → error "path does not exist"). Diffview's base pane
-- is a synthetic buffer named `diffview:///<repo>/.git/:0:/<path>`, and the file
-- panel is `diffview:///panels/0/DiffviewFilePanel` — neither is readable, so
-- the send dies before reaching Claude.
--
-- Diffview knows the real path regardless of which pane you are in:
-- `view:infer_cur_file().absolute_path`. This module resolves through that and
-- hands claudecode a path it will accept.
--
-- Line ranges are only attached when the current buffer IS the working-tree file
-- (buffer name == absolute_path — true for the right pane under --imply-local,
-- and for working-tree diffs). From a base blob the line numbers belong to the
-- old revision, so pointing Claude at those lines in the current file would
-- misdirect it; those sends degrade to a whole-file mention instead.

local M = {}

---@return table|nil view  the Diffview view owning the current tab, if any
local function current_view()
	local ok, lib = pcall(require, "diffview.lib")
	if not ok then
		return nil
	end
	return lib.get_current_view()
end

---Real on-disk path for the entry under the cursor, from any Diffview window.
---@param view table
---@return string|nil path, string|nil err
local function entry_path(view)
	local ok, entry = pcall(function()
		return view:infer_cur_file()
	end)
	if not ok or not entry then
		return nil, "no file under the cursor"
	end
	local path = entry.absolute_path
	if not path or path == "" then
		return nil, "entry has no path on disk"
	end
	if vim.fn.filereadable(path) == 0 then
		-- Deleted on this side of the diff, or a blob with no working-tree twin.
		return nil, "not readable on disk: " .. vim.fn.fnamemodify(path, ":.")
	end
	return path
end

---Visual line range, 0-indexed to match what send_at_mention expects
---(claudecode selection.lua derives lineStart/lineEnd as `lnum - 1`).
---Computed from the live anchor/cursor rather than claudecode's
---visual_commands.get_visual_range(), which is built for tree buffers and falls
---back to the stale '< '> marks here, yielding a range starting at line 1.
---Returns nil outside visual mode, which is what the normal-mode path wants.
---@return integer|nil start_line, integer|nil end_line
local function visual_range_0()
	local mode = vim.api.nvim_get_mode().mode
	if not (mode == "v" or mode == "V" or mode == "\22") then
		return nil, nil
	end
	local anchor, cursor = vim.fn.line("v"), vim.fn.line(".")
	if anchor > cursor then
		anchor, cursor = cursor, anchor
	end
	return anchor - 1, cursor - 1
end

---Send the Diffview entry under the cursor to Claude as an at-mention.
---Returns false when not inside a Diffview view, so callers can fall back to
---the stock claudecode command.
---@param opts { range?: boolean }?  range → attach the visual line range when trustworthy
---@return boolean handled
function M.send(opts)
	opts = opts or {}
	local view = current_view()
	if not view then
		return false
	end

	local path, err = entry_path(view)
	if not path then
		vim.notify("Claude: " .. err, vim.log.levels.WARN)
		return true
	end

	-- Only the buffer that IS the file can supply meaningful line numbers.
	local start_line, end_line
	if opts.range and vim.api.nvim_buf_get_name(0) == path then
		start_line, end_line = visual_range_0()
	end

	local ok, claudecode = pcall(require, "claudecode")
	if not ok then
		vim.notify("Claude: claudecode.nvim not loaded", vim.log.levels.ERROR)
		return true
	end

	local sent, send_err = claudecode.send_at_mention(path, start_line, end_line, "DiffviewSend")
	if not sent then
		vim.notify("Claude: " .. (send_err or "send failed"), vim.log.levels.ERROR)
		return true
	end

	local rel = vim.fn.fnamemodify(path, ":.")
	if start_line then
		vim.notify(("Claude ← %s:%d-%d"):format(rel, start_line + 1, end_line + 1), vim.log.levels.INFO)
	elseif opts.range then
		-- Asked for a range but the buffer is a base blob or the file panel.
		vim.notify(("Claude ← %s (whole file — line numbers are the base revision's)"):format(rel), vim.log.levels.INFO)
	else
		vim.notify(("Claude ← %s"):format(rel), vim.log.levels.INFO)
	end
	return true
end

---Visual <leader>as: Diffview-aware, otherwise the stock :ClaudeCodeSend.
function M.send_visual()
	if not M.send({ range = true }) then
		vim.cmd("ClaudeCodeSend")
	end
end

---Normal <leader>ab: Diffview-aware, otherwise add the current buffer.
function M.add_buffer()
	if not M.send({ range = false }) then
		vim.cmd("ClaudeCodeAdd %")
	end
end

return M

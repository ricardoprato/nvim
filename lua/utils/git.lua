local M = {}

-- Async ahead/behind refresh:
--   * `get_ahead_behind` is a pure read of `_status_cache`. It never blocks and
--     never spawns processes. Statusline render path stays sync.
--   * `_refresh_async` spawns `git rev-list --left-right --count @{upstream}...HEAD`
--     via `vim.system` callback form (not :wait — that pumps the event loop and
--     re-enters the LSP RPC handler with "response id must be a number").
--   * `setup_refresh_triggers` wires `User MiniGitUpdated` and `FocusGained` to
--     `_refresh_async`. The async callback re-emits `User MiniGitUpdated` with
--     `data.source = "async-refresh"` so `format_summary` re-renders without
--     looping back into another refresh.
--   * `_in_flight` coalesces concurrent triggers. Cache stays at the last-known
--     value on timeout / non-zero exit.
M._status_cache = { ahead = 0, behind = 0 }
M._in_flight = false

-- Resolve a git worktree (repo) root via a three-layer fallback (D-16).
--   1. Passed-through `maybe_path` (if non-nil)
--   2. `Snacks.git.get_root()` (when Snacks is loaded)
--   3. `vim.fs.root(bufnr or 0, ".git")` -- independent stdlib walk; covers
--      the early-startup case where Snacks isn't yet loaded. Snacks.git.get_root
--      does NOT internally use vim.fs.root, so this layer is genuine coverage.
-- Returns nil on full failure; callers guard locally (D-17/D-18 -- silent
-- failure, no vim.fn.getcwd() last-resort, no vim.notify).
-- Note: vim.fs.root returns nil for buffers without an on-disk path
-- (e.g. :enew scratch buffers); callers must early-return on nil.
---@param maybe_path? string  candidate path passed in (passthrough if non-nil)
---@param bufnr? integer      buffer to anchor `vim.fs.root` against (default 0)
---@return string?            worktree root, or nil
function M.repo_root(maybe_path, bufnr)
	if maybe_path then
		return maybe_path
	end
	if Snacks and Snacks.git and Snacks.git.get_root then
		local r = Snacks.git.get_root()
		if r then
			return r
		end
	end
	return vim.fs.root(bufnr or 0, ".git")
end

local function _refresh_async(repo_path)
	repo_path = M.repo_root(repo_path)
	if not repo_path then
		return
	end
	if M._in_flight then
		return
	end
	M._in_flight = true

	vim.system(
		{ "git", "-C", repo_path, "rev-list", "--left-right", "--count", "@{upstream}...HEAD" },
		{ text = true, timeout = 2000 },
		vim.schedule_wrap(function(result)
			M._in_flight = false
			if result and result.code == 0 and result.stdout and result.stdout ~= "" then
				local behind, ahead = result.stdout:match("(%d+)%s+(%d+)")
				ahead = tonumber(ahead)
				behind = tonumber(behind)
				if ahead and behind then
					M._status_cache.ahead = ahead
					M._status_cache.behind = behind
				end
			end
			-- Re-emit so format_summary reruns with fresh cache. The
			-- `source = async-refresh` flag is the loop guard read by
			-- setup_refresh_triggers and by the legacy invalidate handler.
			pcall(vim.api.nvim_exec_autocmds, "User", {
				pattern = "MiniGitUpdated",
				data = { source = "async-refresh", buf = vim.api.nvim_get_current_buf() },
			})
		end)
	)
end

M._refresh_async = _refresh_async

-- Sync read of the ahead/behind cache. Never blocks, never spawns.
function M.get_ahead_behind(_repo_path)
	return { ahead = M._status_cache.ahead, behind = M._status_cache.behind }
end

-- Count conflict markers in current buffer
function M.count_conflicts(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return 0
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local count = 0
	for _, line in ipairs(lines) do
		if line:match("^<<<<<<< ") then
			count = count + 1
		end
	end
	return count
end

-- Legacy entry point. The TTL it used to invalidate is gone; force a refresh
-- instead so callers get the freshest value on the next render.
function M.invalidate_cache()
	_refresh_async()
end

-- Background fetch to update remote tracking info. After a successful fetch
-- the ahead/behind cache no longer reflects reality, so kick a refresh.
-- The refresh's MiniGitUpdated re-emit drives the statusline redraw.
function M.background_fetch(repo_path)
	repo_path = M.repo_root(repo_path)
	if not repo_path then
		return
	end

	vim.system({ "git", "-C", repo_path, "fetch", "--quiet" }, { text = true }, function(result)
		if result.code == 0 then
			vim.schedule(function()
				_refresh_async(repo_path)
			end)
		end
	end)
end

-- Timer for periodic fetch
M._fetch_timer = nil

-- Start periodic background fetch (every N minutes)
function M.start_auto_fetch(interval_minutes)
	interval_minutes = interval_minutes or 5
	local interval_ms = interval_minutes * 60 * 1000

	-- Stop existing timer if any
	M.stop_auto_fetch()

	-- Do initial fetch
	M.background_fetch()

	-- Create repeating timer
	M._fetch_timer = vim.uv.new_timer()
	M._fetch_timer:start(
		interval_ms,
		interval_ms,
		vim.schedule_wrap(function()
			M.background_fetch()
		end)
	)
end

-- Stop periodic fetch
function M.stop_auto_fetch()
	if M._fetch_timer then
		M._fetch_timer:stop()
		M._fetch_timer:close()
		M._fetch_timer = nil
	end
end

-- Wire MiniGitUpdated and FocusGained to async refresh. Idempotent — the
-- `custom-config` augroup is shared with the rest of the config; duplicate
-- registration would simply install a second autocmd. Callers are expected
-- to call this once (from lua/plugins/mini.lua).
function M.setup_refresh_triggers()
	_G.Config.new_autocmd("User", "MiniGitUpdated", function(args)
		if args and args.data and args.data.source == "async-refresh" then
			return
		end
		_refresh_async()
	end, "Async refresh ahead/behind on git event")

	_G.Config.new_autocmd("FocusGained", "*", function()
		_refresh_async()
	end, "Async refresh ahead/behind on focus regained")
end

return M

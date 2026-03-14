local M = {}

-- Cache for ahead/behind status (updated on git events)
M._status_cache = {
	ahead = 0,
	behind = 0,
	last_update = 0,
}

-- Get ahead/behind count from remote
-- Returns { ahead = number, behind = number }
function M.get_ahead_behind(repo_path)
	repo_path = repo_path or Snacks.git.get_root()
	if not repo_path then
		return { ahead = 0, behind = 0 }
	end

	-- Use cached value if recent (within 3 seconds)
	local now = vim.uv.now()
	if now - M._status_cache.last_update < 3000 then
		return { ahead = M._status_cache.ahead, behind = M._status_cache.behind }
	end

	-- io.popen: bloqueo a nivel C, no bombea el event loop de Neovim.
	-- vim.system():wait() usa vim.wait() internamente, que sí bombea el event loop
	-- y causa re-entrada en el handler de LSP RPC ("response id must be a number").
	local escaped = "'" .. repo_path:gsub("'", "'\\''") .. "'"
	local handle = io.popen("git -C " .. escaped .. " rev-list --left-right --count @{upstream}...HEAD 2>/dev/null")
	if not handle then
		return { ahead = 0, behind = 0 }
	end
	local result = handle:read("*a")
	handle:close()

	if not result or result == "" then
		return { ahead = 0, behind = 0 }
	end

	local behind, ahead = result:match("(%d+)%s+(%d+)")
	ahead = tonumber(ahead) or 0
	behind = tonumber(behind) or 0

	-- Update cache
	M._status_cache.ahead = ahead
	M._status_cache.behind = behind
	M._status_cache.last_update = now

	return { ahead = ahead, behind = behind }
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

-- Invalidate cache (call on git operations)
function M.invalidate_cache()
	M._status_cache.last_update = 0
end

-- Background fetch to update remote tracking info
-- Runs silently without blocking the UI
function M.background_fetch(repo_path)
	repo_path = repo_path or Snacks.git.get_root()
	if not repo_path then
		return
	end

	-- Use vim.system for async execution (non-blocking)
	vim.system({ "git", "-C", repo_path, "fetch", "--quiet" }, { text = true }, function(result)
		if result.code == 0 then
			-- Invalidate cache after successful fetch
			M.invalidate_cache()
			-- Schedule statusline redraw on main thread
			vim.schedule(function()
				vim.cmd("redrawstatus")
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

return M

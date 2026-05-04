-- lua/utils/multi-claude.lua
--
-- Multi-Session Claude wrapper — thin layer over Snacks.terminal.open() that
-- allows N concurrent freeform-named Claude CLI sessions inside the editor.
-- Spawn / list / switch / rename / close UX wired from lua/plugins/claudecode.lua
-- key entries (<leader>aN/al/aS/aR/aD).
--
-- Buffer naming contract: every session buffer is named "agent:<name>".
-- The "agent:" prefix MUST NOT contain "claude" (substring match) — that
-- would re-engage lua/plugins/persistence.lua:29-31 is_claude predicate
-- and break ephemeral semantics (PROJECT.md locked decision #1 / D-01).
--
-- WHEN BUMPING claudecode.nvim IN lazy-lock.json:
--   1. Spawn an agent via <leader>aN, type a name.
--   2. Inside the agent float, type @ — file-completion popup must appear.
--   3. If popup is missing, the WebSocket port shim broke. Diagnose:
--        :lua =require("claudecode.server.init").state.port
--      If nil/error, the API path moved. Update get_sse_port() below —
--      search for "safe_call" in this file. Pinned commit at Phase 5 author
--      time: claudecode.nvim @ 102d835c (post-v0.3.0).

local M = {}

-- ---------- internal state (module-scoped, ephemeral, in-memory only) ----------
M._sessions = {} -- [id] = { id, name, bufnr, term, alive, last_focused_at }
M._mru_stack = {} -- newest-first list of bufnrs (last_focused_stack per D-02)
M._next_id = 1
M._port_cache = nil -- memoized result of safe_call; nil = not yet probed

-- Soft cap warning threshold (T-05-05 mitigation: surface accidental spawn loops).
local SOFT_CAP = 8

-- ---------- safe_call shim (Pitfall 7 / MCLAUDE-12) ----------
-- pcall-wrapped traversal of dotted module path → field path.
-- Single call site for upstream API drift.
-- @param modpath string — module path passed to require()
-- @return any|nil — value or nil if any step fails (silent; safe_call NEVER notifies)
--
-- Documented fallback path:
--   If get_sse_port() returns nil:
--     Cause 1: claudecode.nvim not yet loaded (user spawned an agent before <leader>ac).
--     Cause 2: upstream renamed/moved the API path (lazy-lock bump regression).
--     Behavior: spawn proceeds WITHOUT CLAUDE_CODE_SSE_PORT in env. Claude CLI runs
--               standalone (no WebSocket diff/MCP integration), but conversation works.
--     Recovery: open the v1.0 singleton with <leader>ac to start the server, then
--               close and re-create agent sessions. Future spawns pick up the cached port.
local function safe_call(modpath, ...)
	local ok, mod = pcall(require, modpath)
	if not ok or not mod then
		return nil
	end
	local obj = mod
	for _, key in ipairs({ ... }) do
		if type(obj) ~= "table" then
			return nil
		end
		obj = obj[key]
		if obj == nil then
			return nil
		end
	end
	return obj
end

-- ---------- shared port resolution ----------
local function get_sse_port()
	if M._port_cache then
		return M._port_cache
	end
	local port = safe_call("claudecode.server.init", "state", "port")
	M._port_cache = port -- cache even nil-on-failure — re-probe is wasteful
	return port
end

-- ---------- name validation + sanitization (T-05-01) ----------
-- @param name string
-- @return boolean valid, string? reason
local function is_valid_name(name)
	if type(name) ~= "string" or name == "" then
		return false, "empty"
	end
	if name:find("[/\\]") then
		return false, "contains path separator"
	end
	if name:find("[%c]") then
		return false, "contains control character"
	end
	if #name > 64 then
		return false, "too long (>64)"
	end
	return true, nil
end

-- ---------- name collision (MCLAUDE-10 / Pitfall 8) ----------
local function name_taken(name)
	for _, s in pairs(M._sessions) do
		if s.alive and s.name == name then
			return true
		end
	end
	return false
end

-- @param base string
-- @return string final_name, boolean suffixed
local function next_available_name(base)
	if not name_taken(base) then
		return base, false
	end
	local i = 2
	while name_taken(base .. "-" .. i) do
		i = i + 1
	end
	return base .. "-" .. i, true
end

-- ---------- MRU stack helpers (D-02) ----------
local function push_mru(buf)
	for i, b in ipairs(M._mru_stack) do
		if b == buf then
			table.remove(M._mru_stack, i)
			break
		end
	end
	table.insert(M._mru_stack, 1, buf)
end

-- ---------- registry lookup helpers ----------
function M.is_session_buf(buf)
	for _, s in pairs(M._sessions) do
		if s.alive and s.bufnr == buf then
			return true
		end
	end
	return false
end

local function session_by_buf(buf)
	for _, s in pairs(M._sessions) do
		if s.alive and s.bufnr == buf then
			return s
		end
	end
	return nil
end

local function session_for_current_buf()
	return session_by_buf(vim.api.nvim_get_current_buf())
end

-- ---------- spawn (MCLAUDE-01) ----------
function M.create(name)
	local valid, reason = is_valid_name(name)
	if not valid then
		Snacks.notify("Invalid agent name (" .. tostring(reason) .. ")", { level = "warn" })
		return nil
	end

	local final_name, suffixed = next_available_name(name)
	if suffixed then
		Snacks.notify(
			"Session '" .. name .. "' exists — created '" .. final_name .. "'",
			{ level = "info" }
		)
	end

	-- Soft cap warning (T-05-05): surface accidental spawn loops.
	local alive_count = #M.list()
	if alive_count >= SOFT_CAP then
		Snacks.notify(
			"You now have " .. (alive_count + 1) .. " active agents — close some with <leader>aD",
			{ level = "warn" }
		)
	end

	local id = M._next_id
	M._next_id = id + 1

	local env = {}
	local port = get_sse_port()
	if port then
		env.CLAUDE_CODE_SSE_PORT = tostring(port)
	end

	local term = Snacks.terminal.open("claude", {
		cwd = vim.fn.getcwd(),
		env = env,
		count = 1000 + id, -- offset out of singleton's count namespace
		bo = { bufhidden = "hide" }, -- preserve scrollback across float-close (MCLAUDE-07)
		win = {
			position = "float",
			width = 0.95,
			height = 0.95,
			border = "rounded",
			title = " agent:" .. final_name .. " ",
			keys = {
				agent_hide = {
					"<C-,>",
					function(self)
						self:hide()
					end,
					mode = "t",
					desc = "Hide agent",
				},
			},
		},
		start_insert = true,
	})

	if not term or not term.buf then
		Snacks.notify("Failed to spawn agent '" .. final_name .. "'", { level = "error" })
		return nil
	end

	-- Rename AFTER snacks finishes its own buffer setup. Calling set_name before the
	-- terminal-job attaches risks BufFilePost firing while ft is still being set.
	-- vim.schedule() defers the rename to the next event-loop tick.
	vim.schedule(function()
		pcall(vim.api.nvim_buf_set_name, term.buf, "agent:" .. final_name)
	end)

	M._sessions[id] = {
		id = id,
		name = final_name,
		bufnr = term.buf,
		term = term,
		alive = true,
		last_focused_at = os.time(),
	}
	push_mru(term.buf)
	return id
end

-- ---------- list (MCLAUDE-02; observable surface for tests + picker) ----------
function M.list()
	local out = {}
	for _, s in pairs(M._sessions) do
		if s.alive then
			table.insert(out, s)
		end
	end
	table.sort(out, function(a, b)
		return a.last_focused_at > b.last_focused_at
	end)
	return out
end

-- ---------- switch (MCLAUDE-03) ----------
function M.switch_to(id)
	local s = M._sessions[id]
	if not s or not s.alive then
		return
	end
	if s.term and s.term.show then
		s.term:show()
	end
	push_mru(s.bufnr)
	s.last_focused_at = os.time()
end

-- D-02 / D-03 — MRU cycle for <leader>aS
function M.switch_mru()
	local alive = M.list()
	if #alive == 0 then
		Snacks.notify("No Claude sessions — press <leader>aN to spawn one", { level = "info" })
		return
	end
	if #alive == 1 then
		return M.switch_to(alive[1].id)
	end
	-- Two or more: pick the second-most-recent (skip current focus)
	local cur_buf = vim.api.nvim_get_current_buf()
	for _, b in ipairs(M._mru_stack) do
		if b ~= cur_buf then
			local s = session_by_buf(b)
			if s then
				return M.switch_to(s.id)
			end
		end
	end
	-- Fallback: oldest from list()
	return M.switch_to(alive[#alive].id)
end

-- ---------- rename (MCLAUDE-04) ----------
function M.rename_current(new_name)
	local s = session_for_current_buf()
	if not s then
		Snacks.notify("Not on an agent: buffer", { level = "warn" })
		return
	end
	local valid, reason = is_valid_name(new_name)
	if not valid then
		Snacks.notify("Invalid agent name (" .. tostring(reason) .. ")", { level = "warn" })
		return
	end
	local final, suffixed = next_available_name(new_name)
	if suffixed then
		Snacks.notify(
			"'" .. new_name .. "' exists — renamed to '" .. final .. "'",
			{ level = "info" }
		)
	end
	s.name = final
	pcall(vim.api.nvim_buf_set_name, s.bufnr, "agent:" .. final)
end

-- ---------- close (MCLAUDE-05) ----------
function M.close_current()
	local s = session_for_current_buf()
	if not s then
		return
	end
	if s.term and s.term.close then
		s.term:close()
	end
	-- registry purge happens in the BufWipeout/TermClose handler (Task 2)
	-- — single source of truth.
end

-- ---------- picker (MCLAUDE-02 / D-04 / D-05) ----------
function M.picker()
	local items = {}
	local cur_buf = vim.api.nvim_get_current_buf()
	for _, s in ipairs(M.list()) do
		table.insert(items, {
			text = "agent:" .. s.name, -- Snacks fuzzy-matches against text
			session_id = s.id,
			bufnr = s.bufnr,
			alive = s.alive,
			is_active = (s.bufnr == cur_buf),
		})
	end
	if #items == 0 then
		Snacks.notify("No Claude sessions — press <leader>aN to spawn one", { level = "info" })
		return
	end
	Snacks.picker.pick({
		source = "select",
		items = items,
		format = function(item)
			local dot = item.alive and "●" or "○"
			local active = item.is_active and " (active)" or ""
			return { { dot .. " " .. item.text .. active } }
		end,
		confirm = function(picker, item)
			picker:close()
			if item and item.session_id then
				M.switch_to(item.session_id)
			end
		end,
	})
end

-- ---------- internal accessors exposed for autocmd module (Task 2) ----------
M._session_by_buf = session_by_buf
M._push_mru = push_mru

-- ---------- autocmd setup (called once at module load) ----------
-- Owns its own augroup ("multi-claude" with clear=true) — does NOT use the
-- project-wide custom-config augroup. Rationale: clear lifecycle ownership;
-- :augroup multi-claude introspectable; clear=true is re-entry-safe (e.g. on
-- :Lazy reload).
--
-- Two cleanup autocmds, exactly two — TermClose and BufWipeout. NEVER BufDelete
-- (claudecode.nvim issue #187 implementation note: cleanup routines should
-- listen exclusively for BufWipeout, not BufDelete, to avoid prematurely
-- removing active sessions; Neovim fires BufDelete when buflisted flips false,
-- which is routine for terminal buffers).
local function setup_autocmds()
	local grp = vim.api.nvim_create_augroup("multi-claude", { clear = true })

	-- TermClose: PTY exited (claude CLI quit, crashed, or /exit). Mark dead so
	-- the picker shows a hollow-dot (○) zombie row, but DO NOT remove from
	-- registry — buffer scrollback is still useful to read.
	vim.api.nvim_create_autocmd("TermClose", {
		group = grp,
		pattern = "*",
		callback = function(args)
			local s = M._session_by_buf(args.buf)
			if s then
				s.alive = false
				Snacks.notify("agent:" .. s.name .. " ended", { level = "info" })
			end
		end,
		desc = "multi-claude: mark session dead on PTY exit (MCLAUDE-07)",
	})

	-- BufWipeout: buffer is wiped (manual :bw!, session-save terminal cleanup,
	-- etc.). Registry + MRU purge. Crucially NOT BufDelete (Pitfall 7 / issue #187).
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = grp,
		pattern = "*",
		callback = function(args)
			for id, s in pairs(M._sessions) do
				if s.bufnr == args.buf then
					M._sessions[id] = nil
					for i, b in ipairs(M._mru_stack) do
						if b == args.buf then
							table.remove(M._mru_stack, i)
							break
						end
					end
					break
				end
			end
		end,
		desc = "multi-claude: purge session record on buffer wipeout",
	})

	-- BufEnter on any buffer: if it is an agent:* session buffer, push to MRU.
	-- Predicate is M.is_session_buf (registry lookup) — NOT a name-string match
	-- (which would race with the deferred nvim_buf_set_name in M.create).
	vim.api.nvim_create_autocmd("BufEnter", {
		group = grp,
		pattern = "*",
		callback = function(args)
			if M.is_session_buf(args.buf) then
				M._push_mru(args.buf)
				local s = M._session_by_buf(args.buf)
				if s then
					s.last_focused_at = os.time()
				end
			end
		end,
		desc = "multi-claude: maintain MRU stack on BufEnter (D-02)",
	})
end

setup_autocmds()
return M

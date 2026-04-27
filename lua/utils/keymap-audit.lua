-- :KeymapAudit baseline reporter.
--
-- Walks runtime keymaps (global + every loaded buffer, modes n/v/x/i/o/t),
-- groups findings into five sections, renders markdown into a readonly
-- scratch buffer (and optionally writes to disk via `:KeymapAudit write`).
--
-- Findings:
--   * Collisions               — same lhs+mode registered 2+ times across any
--                                scope mix (global+buffer shadows included).
--                                Allowlist suppresses by name.
--   * Prefix Blocks Group      — direct keymap whose lhs equals a declared
--                                which-key group prefix.
--   * Undeclared Groups        — `<Leader>X` prefix used in any keymap but
--                                missing from which-key spec.
--   * Dead Targets             — keymap rhs is a literal `<Cmd>edit <path><CR>`
--                                whose path doesn't exist on disk.
--   * Allowlisted              — entries skipped from collision detection,
--                                shown for transparency.
--
-- which-key spec resolution: tries `require("which-key.config").spec` first
-- (and `.options.spec` for older versions), then falls back to parsing
-- `lua/plugins/which-key.lua` source. Both are best-effort; if neither yields
-- groups the audit still runs but flags every used prefix as undeclared.

local M = {}

-- Allowlist: lhs is matched after `nvim_replace_termcodes` normalization, so
-- `<Leader>X` resolves to whatever the runtime leader is. See
-- .planning/phases/01-foundation/01-CONTEXT.md D-14.
M.allowlist = {
	{
		lhs = "<Leader>as",
		modes = { "n", "v" },
		rationale = "claudecode dual-mode (n=tree add file, v=send selection to Claude)",
	},
	{
		lhs = "<Leader>rr",
		modes = { "n", "v" },
		rationale = "kulala ftplugin override of grug-far in http/rest filetypes",
	},
}

local MODES = { "n", "v", "x", "i", "o", "t" }
local LEADER_PREFIX_LEN = 2 -- e.g. "<Leader>g" → "g" is the 1-char group selector

local function norm(lhs)
	if type(lhs) ~= "string" then
		return ""
	end
	return vim.api.nvim_replace_termcodes(lhs, true, true, true)
end

local function tag_filetype(buf)
	local ok, ft = pcall(function()
		return vim.bo[buf].filetype
	end)
	if ok and ft and ft ~= "" then
		return ft
	end
	return "?"
end

local function is_allowlisted(lhs_norm, mode)
	for _, entry in ipairs(M.allowlist) do
		if norm(entry.lhs) == lhs_norm then
			for _, m in ipairs(entry.modes) do
				if m == mode then
					return entry
				end
			end
		end
	end
	return nil
end

-- Walk a which-key spec table recursively, collecting `{ lhs_norm, group_name }`
-- for every entry shaped `{ "<lhs>", group = "..." }`. The spec is a tree of
-- arrays — children appear positionally without keys.
local function walk_spec(spec, out)
	if type(spec) ~= "table" then
		return
	end
	if type(spec[1]) == "string" and type(spec.group) == "string" then
		table.insert(out, { lhs = norm(spec[1]), group = spec.group })
	end
	for _, child in ipairs(spec) do
		if type(child) == "table" then
			walk_spec(child, out)
		end
	end
end

local function parse_which_key_source()
	local path = vim.fn.stdpath("config") .. "/lua/plugins/which-key.lua"
	local f = io.open(path, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	local out = {}
	-- Match { "<leader>X", group = "Name" } in any quote/spacing form.
	for lhs, group in content:gmatch('{%s*"(<[Ll]eader>[^"]*)"%s*,%s*group%s*=%s*"([^"]+)"') do
		table.insert(out, { lhs = norm(lhs), group = group })
	end
	return out
end

local function declared_groups()
	local out = {}

	local ok, wk_config = pcall(require, "which-key.config")
	if ok and wk_config then
		local spec = wk_config.spec
			or (wk_config.options and wk_config.options.spec)
			or (wk_config.defaults and wk_config.defaults.spec)
		if spec then
			walk_spec(spec, out)
		end
	end

	if #out == 0 then
		out = parse_which_key_source()
	end

	return out
end

local function collect_keymaps()
	local entries = {}
	local allowlisted = {}

	local function push(raw, mode, scope, bufnr)
		local lhs_norm = norm(raw.lhs)
		local desc = raw.desc or ""
		local rhs = raw.rhs or ""
		-- Function-form keymaps surface a callback instead of an rhs string.
		local has_callback = raw.callback ~= nil
		local row = {
			lhs_raw = raw.lhs,
			lhs = lhs_norm,
			mode = mode,
			rhs = rhs,
			has_callback = has_callback,
			desc = desc,
			scope = scope,
			bufnr = bufnr,
		}
		local hit = is_allowlisted(lhs_norm, mode)
		if hit then
			row.rationale = hit.rationale
			table.insert(allowlisted, row)
		else
			table.insert(entries, row)
		end
	end

	for _, mode in ipairs(MODES) do
		for _, raw in ipairs(vim.api.nvim_get_keymap(mode)) do
			push(raw, mode, "global", nil)
		end
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				for _, raw in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
					push(raw, mode, "buffer:" .. tag_filetype(buf), buf)
				end
			end
		end
	end

	return entries, allowlisted
end

local function find_collisions(entries)
	local buckets = {}
	for _, e in ipairs(entries) do
		local key = e.mode .. "\0" .. e.lhs
		buckets[key] = buckets[key] or {}
		table.insert(buckets[key], e)
	end
	local out = {}
	for _, bucket in pairs(buckets) do
		if #bucket >= 2 then
			for _, e in ipairs(bucket) do
				table.insert(out, e)
			end
		end
	end
	-- Sort for stable output
	table.sort(out, function(a, b)
		if a.lhs ~= b.lhs then
			return a.lhs < b.lhs
		end
		if a.mode ~= b.mode then
			return a.mode < b.mode
		end
		return (a.scope or "") < (b.scope or "")
	end)
	return out
end

local function find_prefix_blocks_group(entries, declared)
	local declared_set = {}
	for _, g in ipairs(declared) do
		declared_set[g.lhs] = g.group
	end
	local seen = {}
	local out = {}
	for _, e in ipairs(entries) do
		if declared_set[e.lhs] and not seen[e.lhs .. "\0" .. e.mode .. "\0" .. (e.scope or "")] then
			seen[e.lhs .. "\0" .. e.mode .. "\0" .. (e.scope or "")] = true
			local row = vim.deepcopy(e)
			row.group = declared_set[e.lhs]
			table.insert(out, row)
		end
	end
	return out
end

local function find_undeclared_groups(entries, declared)
	local leader = norm("<Leader>")
	if leader == "" then
		return {}
	end
	local declared_prefixes = {}
	for _, g in ipairs(declared) do
		declared_prefixes[g.lhs] = true
	end

	local used_prefixes = {}
	for _, e in ipairs(entries) do
		if e.lhs:sub(1, #leader) == leader then
			-- Need at least one byte after leader for a group prefix
			local after = e.lhs:sub(#leader + 1)
			if #after >= 1 then
				local prefix = leader .. after:sub(1, 1)
				-- Only consider prefixes that have something after them — a
				-- bare <Leader>X without children isn't a "group" yet.
				if #after >= 2 then
					used_prefixes[prefix] = true
				end
			end
		end
	end

	local out = {}
	for prefix in pairs(used_prefixes) do
		if not declared_prefixes[prefix] then
			-- Display form: prefer the suffix character readable
			local suffix = prefix:sub(#leader + 1)
			table.insert(out, { lhs = prefix, suffix = suffix })
		end
	end
	table.sort(out, function(a, b)
		return a.lhs < b.lhs
	end)
	return out
end

local function find_dead_targets(entries)
	local out = {}
	for _, e in ipairs(entries) do
		if not e.has_callback and e.rhs and e.rhs ~= "" then
			-- Match `<Cmd>edit <path><CR>` and `<Cmd>e <path><CR>`
			local path = e.rhs:match("^<[Cc]md>e%s+(.-)<CR>$")
				or e.rhs:match("^<[Cc]md>edit%s+(.-)<CR>$")
			if path then
				path = vim.trim(path)
				if path ~= "" then
					-- Expand $MYVIMRC and other env first
					path = path:gsub("%$MYVIMRC", vim.env.MYVIMRC or "")
					path = path:gsub("vim%.fn%.stdpath%(['\"]config['\"]%)", vim.fn.stdpath("config"))
					path = vim.fn.expand(path)
					if path ~= "" and vim.fn.filereadable(path) == 0 and vim.fn.isdirectory(path) == 0 then
						local row = vim.deepcopy(e)
						row.target_path = path
						table.insert(out, row)
					end
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.lhs < b.lhs
	end)
	return out
end

local function escape_md(s)
	if not s then
		return ""
	end
	-- Wrap in parens: gsub returns (result, count); the count would otherwise
	-- leak as a stray varargs element when used in a table literal.
	return (tostring(s):gsub("|", "\\|"):gsub("\n", " "))
end

local function preview(s, max)
	max = max or 60
	if not s then
		return ""
	end
	if #s > max then
		return s:sub(1, max - 1) .. "…"
	end
	return s
end

local function render_table(rows, header_cols, row_fn)
	if #rows == 0 then
		return "_(none)_\n"
	end
	local lines = {}
	table.insert(lines, "| " .. table.concat(header_cols, " | ") .. " |")
	local sep = {}
	for _ = 1, #header_cols do
		table.insert(sep, "---")
	end
	table.insert(lines, "| " .. table.concat(sep, " | ") .. " |")
	for _, row in ipairs(rows) do
		table.insert(lines, "| " .. table.concat(row_fn(row), " | ") .. " |")
	end
	return table.concat(lines, "\n") .. "\n"
end

local function render(findings)
	local n = {
		col = #findings.collisions,
		pbg = #findings.prefix_blocks_group,
		ug = #findings.undeclared_groups,
		dt = #findings.dead_targets,
		al = #findings.allowlisted,
	}

	local out = {}
	table.insert(
		out,
		string.format(
			"# :KeymapAudit — %d collisions, %d prefix blocks, %d undeclared groups, %d dead targets, %d allowlisted",
			n.col,
			n.pbg,
			n.ug,
			n.dt,
			n.al
		)
	)
	table.insert(out, "")
	table.insert(out, string.format("_Generated: %s_", os.date("%Y-%m-%d %H:%M:%S")))
	table.insert(out, "")

	table.insert(out, "## Collisions")
	table.insert(out, "")
	table.insert(
		out,
		render_table(findings.collisions, { "lhs", "mode", "scope", "desc", "rhs" }, function(e)
			return {
				escape_md(e.lhs_raw or e.lhs),
				e.mode,
				escape_md(e.scope),
				escape_md(e.desc),
				escape_md(preview(e.has_callback and "<callback>" or e.rhs)),
			}
		end)
	)

	table.insert(out, "## Prefix Blocks Group")
	table.insert(out, "")
	table.insert(
		out,
		render_table(findings.prefix_blocks_group, { "lhs", "mode", "group", "desc" }, function(e)
			return {
				escape_md(e.lhs_raw or e.lhs),
				e.mode,
				escape_md(e.group),
				escape_md(e.desc),
			}
		end)
	)

	table.insert(out, "## Undeclared Groups")
	table.insert(out, "")
	table.insert(
		out,
		render_table(findings.undeclared_groups, { "prefix", "suffix char" }, function(e)
			return { escape_md(e.lhs), escape_md(e.suffix) }
		end)
	)

	table.insert(out, "## Dead Targets")
	table.insert(out, "")
	table.insert(
		out,
		render_table(findings.dead_targets, { "lhs", "mode", "scope", "rhs", "missing path" }, function(e)
			return {
				escape_md(e.lhs_raw or e.lhs),
				e.mode,
				escape_md(e.scope),
				escape_md(preview(e.rhs)),
				escape_md(e.target_path),
			}
		end)
	)

	table.insert(out, "## Allowlisted")
	table.insert(out, "")
	table.insert(
		out,
		render_table(findings.allowlisted, { "lhs", "mode", "scope", "rationale" }, function(e)
			return {
				escape_md(e.lhs_raw or e.lhs),
				e.mode,
				escape_md(e.scope),
				escape_md(e.rationale),
			}
		end)
	)

	return table.concat(out, "\n")
end

local function open_in_scratch(markdown)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(markdown, "\n", { plain = true }))
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true
	vim.api.nvim_buf_set_name(buf, "[KeymapAudit]")
	vim.api.nvim_set_current_buf(buf)
end

local function write_to_disk(write_path, markdown)
	local parent = vim.fn.fnamemodify(write_path, ":h")
	if parent ~= "" and vim.fn.isdirectory(parent) == 0 then
		vim.fn.mkdir(parent, "p")
	end
	vim.fn.writefile(vim.split(markdown, "\n", { plain = true }), write_path)
end

function M.run(write_path)
	local entries, allowlisted = collect_keymaps()
	local declared = declared_groups()

	local findings = {
		collisions = find_collisions(entries),
		prefix_blocks_group = find_prefix_blocks_group(entries, declared),
		undeclared_groups = find_undeclared_groups(entries, declared),
		dead_targets = find_dead_targets(entries),
		allowlisted = allowlisted,
	}

	local md = render(findings)
	open_in_scratch(md)
	if write_path and write_path ~= "" then
		write_to_disk(write_path, md)
		vim.notify(string.format("KeymapAudit: wrote %s", write_path), vim.log.levels.INFO)
	end
	return findings
end

return M

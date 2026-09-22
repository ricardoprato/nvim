-- Project-swap confirm. Wired as the `confirm` action of `Snacks.picker.projects`.
-- Changes the global cwd to the picked project and nothing else: open buffers are
-- kept across swaps (no session save/close/restore). Persistence still auto-saves
-- per-cwd on exit via its own autocmds; the swap just doesn't touch sessions.
--
-- MiniMisc auto_root (mini.lua) re-anchors cwd to the focused buffer's project on
-- every BufEnter, so an explicit chdir alone does not survive: the window still
-- shows a file from the previous project, and the next BufEnter drags cwd back
-- to that file's root. Landing on an empty, unnamed buffer is what makes the
-- swap stick — `MiniMisc.find_root` bails on `nvim_buf_get_name(buf) == ''`, so
-- an unnamed buffer is the one state auto_root leaves alone.
--
-- The stale BufEnter queued by `picker:close()` is harmless: auto_root's handler
-- is `vim.schedule_wrap`ped and drops any event whose buffer is no longer current,
-- and by the time it runs the empty buffer is. Re-picking the current cwd is a no-op.
local function project_swap_confirm(picker, item)
	-- Expected exit, not a swallowed error: snacks calls `confirm` with no item
	-- when the list is empty, and oldfiles entries can arrive without a `file`.
	-- Nothing to swap to, so leave the picker open and let the user pick again.
	if not item or not item.file then
		return
	end
	picker:close()

	-- `recent = true` feeds this picker from oldfiles, which still lists projects
	-- that were since deleted, renamed or moved. Failing silently here would close
	-- the picker as if the swap worked and leave every later <leader>ff scoped to
	-- the previous project, so say it out loud.
	local target = item.file
	if vim.fn.isdirectory(target) ~= 1 then
		vim.notify(("Project path no longer exists: %s"):format(target), vim.log.levels.WARN)
		return
	end

	if vim.fn.getcwd() == target then
		return
	end

	-- `isdirectory` proves the path exists, not that it can be entered: a directory
	-- with no execute bit, or a stale mountpoint, passes that guard and makes chdir
	-- throw E472. Let it through and the failure surfaces as a raw stack trace from
	-- inside a picker callback, which says nothing about which project failed.
	local ok, err = pcall(vim.fn.chdir, target)
	if not ok then
		vim.notify(("Could not enter project: %s (%s)"):format(target, err), vim.log.levels.WARN)
		return
	end

	-- Reuse the buffer when it is already unnamed (a previous swap's landing pad,
	-- the dashboard): `enew` on every swap would stack "[No Name]" entries in the
	-- mini.tabline. `modified` is checked because an unnamed buffer can still hold
	-- unsaved scratch text, and `enew` would hide it behind the new one.
	local buf = vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified then
		return
	end

	vim.cmd.enew()
end

-- Shared by both project pickers below. They have to agree on what counts as a
-- project root: a marker listed in one and not the other means the same repo is
-- offered by <leader>fp and missing from <leader>sp.
--
-- Keep this list identical to the one MiniMisc.setup_auto_root gets in
-- lua/plugins/mini.lua. A marker added here and not there makes the picker offer a
-- root that `find_root` does not recognise, so the swap lands and the next
-- BufEnter drags cwd back to the previous project — the exact failure the header
-- comment above describes.
local project_patterns = { ".odoo_lsp", ".git", "package.json", "pyproject.toml" }
-- Snacks defaults this to 2, which only reaches `<scanned root>/<dir>/<project>`;
-- client repos here sit a level deeper. The cost is a full breadth walk to depth
-- 4, not a cheaper one: snacks' fd invocation carries no `--prune`, so it keeps
-- descending through directories that already matched, and a repo nested inside
-- another repo shows up as its own entry. That is accepted — vendored trees stay
-- out because fd honours .gitignore (snacks passes no `--no-ignore`), so a
-- gitignored `node_modules` never reaches the list despite `package.json` being
-- one of the patterns above.
local project_max_depth = 4

-- Builders, not constants: each call hands the picker a table of its own, so
-- whatever snacks does to `opts` cannot leak into the next invocation.
--
-- <leader>fp (global find): default snacks projects behavior + atomic-swap
-- confirm. Includes oldfiles via `recent = true` so any recently visited project
-- is reachable regardless of where nvim was launched.
local function project_picker_opts()
	return {
		patterns = project_patterns,
		max_depth = project_max_depth,
		recent = true,
		confirm = project_swap_confirm,
	}
end

-- <leader>sp (scoped swap): only lists projects whose root pattern lives under
-- the launch directory. `dev` tells fd which roots to scan; `recent = false`
-- suppresses the oldfiles fallback so the picker stays strictly local. Useful
-- when nvim is launched at a workspace root containing many sibling repos.
--
-- `_G.Config.initial_cwd` (init.lua) is the single source of truth for the launch
-- directory, captured before lazy.nvim evaluates any spec. It stays frozen while
-- project swaps chdir around it, which is exactly the scope this picker wants.
local function project_picker_opts_scoped()
	return {
		patterns = project_patterns,
		max_depth = project_max_depth,
		dev = { _G.Config.initial_cwd },
		recent = false,
		confirm = project_swap_confirm,
	}
end

local spec = {
	"folke/snacks.nvim",
	-- Eager on purpose, despite the `keys` below. `Snacks.setup` sets
	-- 'statuscolumn' inline and arms the rest off editor events (snacks/init.lua:156)
	-- — `bigfile` and `image` on BufReadPre, `indent` on BufReadPost, `dashboard`,
	-- `scroll`, `input` and `picker` on UIEnter. A lazy trigger would run setup after
	-- those events had already passed, so the buffers opened at startup would keep
	-- the default statuscolumn and never get the handlers. `priority` only orders
	-- specs that are already `lazy = false`: 1000 matches theme.lua and outranks
	-- mini.lua's 900, so snacks is in place before mini installs its tabline and
	-- auto_root.
	priority = 1000,
	lazy = false,
	opts = {
		-- Replacements for mini modules
		dashboard = {
			enabled = true,
			preset = {
				keys = {
					{ icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
					{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
					{
						icon = " ",
						key = "g",
						desc = "Find Text",
						action = ":lua Snacks.dashboard.pick('live_grep')",
					},
					{
						icon = " ",
						key = "r",
						desc = "Recent Files",
						action = ":lua Snacks.dashboard.pick('oldfiles')",
					},
					-- Dashboard projects entry uses default Snacks opts (no custom confirm),
					-- so picking from the dashboard does NOT trigger the project-swap
					-- orchestrator. This is for cold-start discoverability; in-session
					-- swaps go through <leader>fp / <leader>sp which carry the orchestrator.
					{ icon = " ", key = "p", desc = "Projects", action = ":lua Snacks.picker.projects()" },
					{
						icon = " ",
						key = "c",
						desc = "Config",
						action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
					},
					{ icon = " ", key = "s", desc = "Restore Session", section = "session" },
					{ icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy" },
					{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
				},
				header = [[
 ███╗   ██╗██╗   ██╗██╗███╗   ███╗
 ████╗  ██║██║   ██║██║████╗ ████║
 ██╔██╗ ██║██║   ██║██║██╔████╔██║
 ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
 ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
 ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝]],
			},
		},
		-- `top_down = false` anchors toasts to bottom-right and stacks upward.
		-- snacks.notifier has no free `position` knob; X is always right-edge.
		notifier = { enabled = true, top_down = false },
		picker = { enabled = true },
		-- explorer disabled: mini.files owns the file-tree surface (lua/plugins/mini.lua).
		-- Keymaps <leader>ed / <leader>ef moved there.
		explorer = { enabled = false },
		indent = { enabled = true },
		-- Slower than the stock step = 10 / total = 200 (scroll.lua:30): a longer
		-- glide reads as motion rather than a jump, which is the point of the
		-- one-line-per-wheel-notch scrolling set in lua/config/options.lua.
		--
		-- This only covers the first notch after a pause. Anything within 100ms of
		-- the previous scroll takes the `animate_repeat` branch (scroll.lua:305),
		-- left at its stock step = 5 / total = 50 on purpose: spinning the wheel
		-- should track the hand, not queue up a quarter-second glide per notch.
		scroll = { enabled = true, animate = { duration = { step = 15, total = 250 } } },
		bigfile = { enabled = true },
		words = { enabled = true },

		-- Only modules snacks arms itself need an entry: `M.config` returns a bare
		-- table for an unlisted key (snacks/init.lua:50), so an absent module never
		-- passes the `.enabled` check that dispatches it. The on-demand APIs — zen,
		-- dim, rename, lazygit, terminal, toggle, bufdelete, animate — read nothing
		-- from here and are reached through `Snacks.*` directly, same as `git` and
		-- `gitbrowse` further down. `enabled = true` is itself redundant (naming the
		-- key is the enable, snacks/init.lua:152); it stays as the readable spelling.
		image = { enabled = true },
		input = { enabled = true },
		statuscolumn = { enabled = true },
	},
	keys = {
		-- Picker (replacing mini.pick mappings)
		{
			"<leader><space>",
			function()
				Snacks.picker.smart()
			end,
			desc = "Smart Find Files",
		},
		{
			"<leader>ff",
			function()
				Snacks.picker.files()
			end,
			desc = "Files",
		},
		{
			"<leader>fg",
			function()
				Snacks.picker.grep()
			end,
			desc = "Grep",
		},
		{
			"<leader>fF",
			function()
				Snacks.picker.files({ cwd = _G.Config.initial_cwd })
			end,
			desc = "Files (launch dir)",
		},
		{
			"<leader>fG",
			function()
				Snacks.picker.grep({ cwd = _G.Config.initial_cwd })
			end,
			desc = "Grep (launch dir)",
		},
		{
			"<leader>fb",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Buffers",
		},
		{
			"<leader>fh",
			function()
				Snacks.picker.help()
			end,
			desc = "Help tags",
		},
		{
			"<leader>fr",
			function()
				Snacks.picker.resume()
			end,
			desc = "Resume",
		},
		{
			"<leader>fd",
			function()
				Snacks.picker.diagnostics()
			end,
			desc = "Diagnostics workspace",
		},
		{
			"<leader>fD",
			function()
				Snacks.picker.diagnostics_buffer()
			end,
			desc = "Diagnostics buffer",
		},
		{
			"<leader>fc",
			function()
				Snacks.picker.commands()
			end,
			desc = "Commands (Ex palette)",
		},
		{
			"<leader>fC",
			function()
				Snacks.picker.colorschemes()
			end,
			desc = "Colorschemes",
		},
		{
			"<leader>fs",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "LSP Symbols",
		},
		{
			"<leader>fS",
			function()
				Snacks.picker.lsp_workspace_symbols()
			end,
			desc = "LSP Workspace Symbols",
		},
		{
			"<leader>fR",
			function()
				Snacks.picker.lsp_references()
			end,
			desc = "References (LSP)",
		},
		{
			"<leader>fl",
			function()
				Snacks.picker.lines()
			end,
			desc = "Lines (buf)",
		},
		{
			"<leader>fw",
			function()
				Snacks.picker.grep_word()
			end,
			desc = "Grep current word",
		},
		{
			"<leader>fH",
			function()
				Snacks.picker.highlights()
			end,
			desc = "Highlight groups",
		},
		{
			"<leader>f/",
			function()
				Snacks.picker.search_history()
			end,
			desc = '"/" history',
		},
		{
			"<leader>f:",
			function()
				Snacks.picker.command_history()
			end,
			desc = '":" history',
		},
		{
			"<leader>fv",
			function()
				Snacks.picker.recent()
			end,
			desc = "Recent files",
		},
		{
			"<leader>fp",
			function()
				Snacks.picker.projects(project_picker_opts())
			end,
			desc = "Projects",
		},
		{
			"<leader>sp",
			function()
				Snacks.picker.projects(project_picker_opts_scoped())
			end,
			desc = "Projects under launch cwd (swap)",
		},
		-- Explorer moved to mini.files (<leader>ed / <leader>ef in lua/plugins/mini.lua).

		-- Notifications history (replacing mini.notify)
		{
			"<leader>en",
			function()
				Snacks.notifier.show_history()
			end,
			desc = "Notifications",
		},

		-- Buffer delete (replacing mini.bufremove)
		{
			"<leader>bd",
			function()
				Snacks.bufdelete()
			end,
			desc = "Delete",
		},
		{
			"<leader>bD",
			function()
				Snacks.bufdelete.other()
			end,
			desc = "Delete others",
		},
		{
			"<leader>be",
			function()
				-- `M.all()`, not `M.delete({ force = true })`: without a `filter` the
				-- latter falls through to `opts.buf or 0` and force-deletes only the
				-- current buffer, discarding its unsaved changes under a "Delete all"
				-- label. No `force` here — a modified buffer should still stop this.
				Snacks.bufdelete.all()
			end,
			desc = "Delete all",
		},

		-- Words navigation
		{
			"]]",
			function()
				Snacks.words.jump(1)
			end,
			desc = "Next reference",
			mode = { "n", "x" },
		},
		{
			"[[",
			function()
				Snacks.words.jump(-1)
			end,
			desc = "Prev reference",
			mode = { "n", "x" },
		},

		-- Git surface owned here:
		--   <leader>gb  blame_line       Snacks.git.blame_line
		--   <leader>gB  branches picker  Snacks.picker.git_branches
		--   <leader>gl  repo log picker  Snacks.picker.git_log
		--   <leader>gL  buf log picker   Snacks.picker.git_log({ current_file = true, follow = true })
		--   <leader>gs  status picker    Snacks.picker.git_status
		--   <leader>gS  stash picker     Snacks.picker.git_stash
		--   <leader>go  gitbrowse file   Snacks.gitbrowse
		--   <leader>gO  gitbrowse repo   Snacks.gitbrowse({ what = "repo" })
		--   <leader>tg  lazygit TUI      Snacks.lazygit
		-- Owned elsewhere:
		--   <leader>gc/gC/gp/gP/g-       mini.git :Git wrapper (lua/plugins/mini.lua)
		--   <leader>og                   mini.diff overlay (lua/plugins/mini.lua)
		--   <leader>gd                   diffview working-tree (lua/plugins/diffview.lua)
		--   <leader>gv                   diffview toggle/conflict/range (lua/plugins/diffview.lua)
		--   <leader>gr/gR                diffview review vs base branch (lua/plugins/diffview.lua)
		-- Not installed: gitsigns (mini.diff owns gutter), neogit (lazygit owns TUI),
		--                vim-fugitive (mini.git owns :Git).

		{
			"<leader>gb",
			function()
				Snacks.git.blame_line()
			end,
			desc = "Git blame line",
		},
		{
			"<leader>gB",
			function()
				Snacks.picker.git_branches()
			end,
			desc = "Git branches",
		},
		{
			"<leader>gs",
			function()
				Snacks.picker.git_status()
			end,
			desc = "Git status",
		},
		{
			"<leader>go",
			function()
				Snacks.gitbrowse()
			end,
			desc = "Git browse (file)",
			mode = { "n", "x" },
		},
		{
			"<leader>gO",
			function()
				Snacks.gitbrowse({ what = "repo" })
			end,
			desc = "Git browse (repo)",
		},
		{
			"<leader>gS",
			function()
				Snacks.picker.git_stash()
			end,
			desc = "Git Stash",
		},
		{
			"<leader>gl",
			function()
				Snacks.picker.git_log()
			end,
			desc = "Git log (repo)",
		},
		{
			"<leader>gL",
			function()
				Snacks.picker.git_log({ current_file = true, follow = true })
			end,
			desc = "Git log (buffer)",
		},
		-- Surfaces mini never provided: terminal-backed TUIs (<leader>t*), file
		-- rename, and zen/zoom.
		{
			"<leader>tg",
			function()
				Snacks.lazygit()
			end,
			desc = "Lazygit",
		},
		{
			"<leader>td",
			function()
				local buf = vim.api.nvim_buf_get_name(0)
				local start = buf ~= "" and vim.fs.dirname(buf) or vim.fn.getcwd()
				local found = vim.fs.find(
					{ "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml" },
					{ upward = true, path = start, type = "file" }
				)[1]
				local cmd = "lazydocker"
				local cwd = vim.fn.getcwd()
				if found then
					cwd = vim.fs.dirname(found)
					-- Mirror docker compose's default project-name sanitization:
					-- lowercase the dir basename, drop anything outside [a-z0-9_-],
					-- then trim leading `_`/`-`. That last step is compose's own
					-- TrimLeft and it is not cosmetic: for a directory like
					-- `_Client-Demo.x`, compose names the project `client-demox`
					-- while stopping at the character filter yields `_client-demox`.
					-- lazydocker would then filter on a project that does not exist
					-- and show an empty TUI, as if Docker had nothing running.
					local project = vim.fs.basename(cwd):lower():gsub("[^a-z0-9_-]", ""):gsub("^[_-]+", "")
					if project ~= "" then
						cmd = "lazydocker -p " .. project
					end
				end
				Snacks.terminal(cmd, { cwd = cwd })
			end,
			desc = "Lazydocker (project-aware)",
		},
		{
			"<leader>tf",
			function()
				Snacks.terminal()
			end,
			desc = "Terminal (float)",
		},
		{
			"<leader>eR",
			function()
				Snacks.rename.rename_file()
			end,
			desc = "Rename file",
		},
		{
			"<leader>z",
			function()
				Snacks.zen()
			end,
			desc = "Toggle Zen Mode",
		},
		{
			"<leader>Z",
			function()
				Snacks.zen.zoom()
			end,
			desc = "Toggle Zoom",
		},
	},
	init = function()
		-- Own augroup with `clear = true`: `init` runs again on `:Lazy reload
		-- snacks.nvim`, and without it a second VeryLazy handler stacks on the first
		-- and re-registers every toggle keymap below. This is plugin-level, so it
		-- does not go through `_G.Config.new_autocmd` — that wrapper shares the
		-- `custom-config` group, which only clears when init.lua itself re-runs.
		vim.api.nvim_create_autocmd("User", {
			group = vim.api.nvim_create_augroup("snacks-toggles", { clear = true }),
			pattern = "VeryLazy",
			desc = "Register snacks toggle keymaps",
			callback = function()
				Snacks.toggle.option("spell", { name = "Spelling" }):map("\\s")
				Snacks.toggle.option("wrap", { name = "Wrap" }):map("\\w")
				Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("\\r")
				Snacks.toggle.diagnostics():map("\\d")
				Snacks.toggle.inlay_hints():map("\\h")
				Snacks.toggle.dim():map("<leader>od")
				Snacks.toggle
					.option("background", { off = "light", on = "dark", name = "Dark Background" })
					:map("<leader>ob")
			end,
		})
	end,
}

return spec

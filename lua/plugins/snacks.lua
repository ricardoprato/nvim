-- Captured at module load (lazy.nvim evals plugin specs before any DirChanged),
-- so this is the directory nvim was launched from. Frozen — subsequent project
-- swaps (which call vim.fn.chdir) won't shift this value, which is exactly what
-- we want for the <leader>sp scope.
local startup_cwd = vim.fn.getcwd()

-- Project-swap confirm. Wired as the `confirm` action of `Snacks.picker.projects`.
-- Changes the global cwd to the picked project and nothing else: open buffers are
-- kept across swaps (no session save/close/restore). Persistence still auto-saves
-- per-cwd on exit via its own autocmds; the swap just doesn't touch sessions.
--
-- MiniMisc auto_root (mini.lua) re-anchors cwd to the focused buffer's project on
-- the next BufEnter, so cwd ends up tracking whichever buffer you're on. This
-- explicit chdir only sets the immediate cwd so a follow-up find-files is scoped
-- to the project just picked. Re-picking the current cwd is a no-op.
local function project_swap_confirm(picker, item)
	if not item or not item.file then
		return
	end
	picker:close()

	local target = item.file
	if vim.fn.isdirectory(target) ~= 1 then
		return
	end

	if vim.fn.getcwd() == target then
		return
	end

	vim.fn.chdir(target)
end

-- Builder for <leader>fp (global find): default snacks projects behavior +
-- atomic-swap confirm. Includes oldfiles via `recent = true` so any recently
-- visited project is reachable regardless of where nvim was launched.
local function project_picker_opts()
	return {
		patterns = { ".odoo_lsp", ".git", "package.json", "pyproject.toml" },
		max_depth = 4,
		recent = true,
		confirm = project_swap_confirm,
	}
end

-- Builder for <leader>sp (scoped swap): only lists projects whose root pattern
-- lives under `startup_cwd`. `dev` tells fd which roots to scan; `recent=false`
-- suppresses the oldfiles fallback so the picker stays strictly local. Useful
-- when nvim is launched at a workspace root containing many sibling repos.
local function project_picker_opts_scoped()
	return {
		patterns = { ".odoo_lsp", ".git", "package.json", "pyproject.toml" },
		max_depth = 4,
		dev = { startup_cwd },
		recent = false,
		confirm = project_swap_confirm,
	}
end

local spec = {
	"folke/snacks.nvim",
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
					{
						icon = "󰒲 ",
						key = "L",
						desc = "Lazy",
						action = ":Lazy",
						enabled = package.loaded.lazy ~= nil,
					},
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
		notifier = { enabled = true, timeout = 3000, top_down = false },
		picker = { enabled = true },
		-- explorer disabled: mini.files owns the file-tree surface (lua/plugins/mini.lua).
		-- Keymaps <leader>ed / <leader>ef moved there.
		explorer = { enabled = false },
		indent = { enabled = true, animate = { enabled = true } },
		scroll = { enabled = true, animate = { duration = { step = 15, total = 250 } } },
		bigfile = { enabled = true },
		bufdelete = { enabled = true },
		words = { enabled = true },

		animate = { enabled = true },
		zen = { enabled = true },
		dim = { enabled = true },
		image = { enabled = true },
		input = { enabled = true },
		rename = { enabled = true },
		lazygit = { enabled = true },
		terminal = { enabled = true },
		statuscolumn = { enabled = true },
		toggle = { enabled = true },

		-- Styles
		styles = {},
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
				Snacks.bufdelete.delete({ force = true })
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
		--   <leader>gd                   diffview working-tree (lua/plugins/editor.lua)
		--   <leader>gv                   diffview toggle/conflict/range (lua/plugins/editor.lua)
		--   <leader>gr/gR                diffview review vs base branch (lua/plugins/editor.lua)
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
		-- New features
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
					-- lowercase the dir basename, drop anything outside [a-z0-9_-].
					local project = vim.fs.basename(cwd):lower():gsub("[^a-z0-9_-]", "")
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
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			callback = function()
				-- Setup toggles
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

-- Cold-start detection (D-04): true iff fresh nvim with no real project buffers loaded.
-- Excludes [No Name], dashboard scratch, and unlisted helper buffers via the
-- named-and-listed filter — argc()==0 alone is not robust because nvim seeds
-- a [No Name] buffer at startup.
local function is_cold_start()
	if vim.fn.argc() ~= 0 then
		return false
	end
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if
			vim.api.nvim_buf_is_loaded(b)
			and vim.bo[b].buftype == ""
			and vim.api.nvim_buf_get_name(b) ~= ""
			and vim.fn.buflisted(b) == 1
		then
			return false
		end
	end
	return true
end

-- D-02 atomic project-swap orchestrator. Wired as the `confirm` action of
-- `Snacks.picker.projects` so picking a project triggers:
--   1. Snapshot Project A's session (PersistenceSavePre at persistence.lua:14-25
--      already filters terminal/nofile so they don't land in the snapshot).
--   2. Silent `:wa` to flush modified writable buffers (D-01).
--   3. Close all `buftype==""` buffers; skip terminal/nofile so the floating
--      Claude Code chat survives the swap.
--   4. `vim.fn.chdir(target)` — global chdir; doesn't fire DirChanged so
--      MiniMisc auto-root won't fight the chdir until next BufEnter.
--   5. `persistence.load()` — sources B's session for the current branch
--      (cwd+branch keying via `branch = true` set in Plan 02-02).
-- Save failure aborts the swap (no partial state). Same-session re-pick is a no-op.
local function project_swap_confirm(picker, item)
	if not item or not item.file then
		return
	end
	picker:close()

	local target = item.file
	if vim.fn.isdirectory(target) ~= 1 then
		return
	end

	-- Same-session no-op (avoid round-trip when re-picking current project)
	if vim.v.this_session ~= "" and vim.fn.getcwd() == target then
		return
	end

	if not is_cold_start() then
		local persistence = require("persistence")

		local save_ok = pcall(persistence.save)
		if not save_ok then
			vim.notify("project swap aborted: persistence.save() failed", vim.log.levels.ERROR)
			return
		end

		pcall(vim.cmd, "silent! wa")

		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
				pcall(vim.api.nvim_buf_delete, buf, { force = false })
			end
		end
	end

	vim.fn.chdir(target)
	pcall(require("persistence").load)
end

-- Builder for the project picker opts table. Used by both <leader>fp and
-- <leader>sp keymaps so changes here apply uniformly.
local function project_picker_opts()
	return {
		dev = { "~/odoo/17.0", "~/odoo/18.0", "~/odoo/19.0", "~/dev" },
		patterns = { ".odoo_lsp", "__manifest__.py", ".git", "package.json", "pyproject.toml" },
		recent = true,
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
					-- NOTE: dashboard projects entry uses default Snacks opts (no custom confirm),
					-- so picking from the dashboard does NOT trigger the D-02 orchestrator.
					-- This is for cold-start discoverability; in-session swaps go through
					-- <leader>fp / <leader>sp which carry the orchestrator.
					{ icon = " ", key = "p", desc = "Projects", action = ":lua Snacks.picker.projects()" },
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
		notifier = { enabled = true, timeout = 3000 },
		picker = { enabled = true },
		explorer = { enabled = true },
		indent = { enabled = true, animate = { enabled = true } },
		scroll = { enabled = true, animate = { duration = { step = 15, total = 250 } } },
		bigfile = { enabled = true },
		bufdelete = { enabled = true },
		words = { enabled = true },

		-- New features (Phase 3b)
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
				Snacks.picker.git_log()
			end,
			desc = "Commits (all)",
		},
		{
			"<leader>fC",
			function()
				Snacks.picker.git_log({ current_file = true })
			end,
			desc = "Commits (buf)",
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
				Snacks.picker.projects(project_picker_opts())
			end,
			desc = "Projects (swap session)",
		},
		-- Explorer (replacing mini.files)
		{
			"<leader>ed",
			function()
				Snacks.explorer()
			end,
			desc = "Explorer (cwd)",
		},
		{
			"<leader>ef",
			function()
				Snacks.explorer({ cwd = vim.fn.expand("%:p:h") })
			end,
			desc = "Explorer (file dir)",
		},

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

		-- Git
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
			"<leader>gd",
			function()
				Snacks.picker.git_diff()
			end,
			desc = "Git Diff (Hunks)",
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
				Snacks.terminal("lazydocker")
			end,
			desc = "Lazydocker",
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
				Snacks.toggle.dim():map("<leader>uD")
			end,
		})
	end,
}

return spec

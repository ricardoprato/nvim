return {
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
				Snacks.picker.projects()
			end,
			desc = "Projects",
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
				Snacks.bufdelete.delete()
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

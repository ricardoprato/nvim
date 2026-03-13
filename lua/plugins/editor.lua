return {
	-- Obsidian
	{
		"obsidian-nvim/obsidian.nvim",
		event = {
			"BufReadPre " .. vim.fn.expand("~") .. "/obsidian/**.md",
			"BufNewFile " .. vim.fn.expand("~") .. "/obsidian/**.md",
		},
		cmd = "Obsidian",
		keys = {
			{ "<leader>nn", "<Cmd>Obsidian new<CR>", desc = "New note" },
			{ "<leader>no", "<Cmd>Obsidian open<CR>", desc = "Open in app" },
			{ "<leader>ns", "<Cmd>Obsidian search<CR>", desc = "Search" },
			{ "<leader>nd", "<Cmd>Obsidian today<CR>", desc = "Daily note" },
			{ "<leader>ny", "<Cmd>Obsidian yesterday<CR>", desc = "Yesterday" },
			{ "<leader>nm", "<Cmd>Obsidian tomorrow<CR>", desc = "Tomorrow" },
			{ "<leader>nb", "<Cmd>Obsidian backlinks<CR>", desc = "Backlinks" },
			{ "<leader>nl", "<Cmd>Obsidian links<CR>", desc = "Links" },
			{ "<leader>nt", "<Cmd>Obsidian template<CR>", desc = "Template" },
		},
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			workspaces = { { name = "personal", path = "~/obsidian" } },
			legacy_commands = false,
		},
	},

	-- Render Markdown
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = "markdown",
		opts = { file_types = { "markdown" } },
	},

	-- Diffview
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose" },
		keys = {
			{ "<leader>gv", "<Cmd>DiffviewOpen<CR>", desc = "Diffview open" },
			{ "<leader>gV", "<Cmd>DiffviewClose<CR>", desc = "Diffview close" },
		},
		opts = { use_icons = true },
	},

	-- Grug-far (search & replace)
	{
		"MagicDuck/grug-far.nvim",
		cmd = "GrugFar",
		keys = {
			{ "<leader>rr", "<Cmd>GrugFar<CR>", desc = "Search & Replace" },
			{
				"<leader>rw",
				function()
					require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
				end,
				desc = "Replace word under cursor",
			},
			{
				"<leader>rf",
				function()
					require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
				end,
				desc = "Replace in file",
			},
			{
				"<leader>rr",
				function()
					require("grug-far").with_visual_selection()
				end,
				mode = "x",
				desc = "Replace selection",
			},
		},
		opts = {},
	},

	-- vim-sleuth (auto detect indent)
	{ "tpope/vim-sleuth", event = { "BufReadPost", "BufNewFile" } },

	-- Kulala (HTTP client)
	{
		"mistweaverco/kulala.nvim",
		ft = { "http", "rest" },
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			display_mode = "float",
			split_direction = "vertical",
			default_formatters = {
				json = { "jq", "-r" },
				xml = { "xmllint", "--format", "-" },
				html = { "xmllint", "--format", "--html", "-" },
			},
			icons = {
				inlay = { loading = "⏳", done = "✅", error = "❌" },
			},
			additional_curl_options = {},
		},
	},
}

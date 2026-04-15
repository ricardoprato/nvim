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
			-- Daily & weekly
			{ "<leader>nd", "<Cmd>Obsidian today<CR>", desc = "Work daily (today)" },
			{ "<leader>ny", "<Cmd>Obsidian yesterday<CR>", desc = "Yesterday" },
			{ "<leader>nm", "<Cmd>Obsidian tomorrow<CR>", desc = "Tomorrow" },
			{
				"<leader>nw",
				function()
					local week = os.date("%Y-W%W")
					local path = vim.fn.expand("~/obsidian/personal/" .. week .. ".md")
					if vim.fn.filereadable(path) == 1 then
						vim.cmd("edit " .. vim.fn.fnameescape(path))
					else
						require("obsidian.actions").new_from_template("personal/" .. week, "personal-weekly")
					end
				end,
				desc = "Personal weekly",
			},

			-- Quick capture to specific folders
			{
				"<leader>nz",
				function()
					local title = vim.fn.input("Zettel: ")
					if title == "" then return end
					require("obsidian.actions").new_from_template("zettelkasten/" .. title, "zettel")
				end,
				desc = "New zettel",
			},
			{
				"<leader>nc",
				function()
					local title = vim.fn.input("Capture: ")
					if title == "" then return end
					require("obsidian.actions").new_from_template("inbox/" .. title, nil)
				end,
				desc = "Quick capture (inbox)",
			},
			{
				"<leader>ni",
				function()
					local title = vim.fn.input("Idea: ")
					if title == "" then return end
					require("obsidian.actions").new_from_template("personal/" .. title, "idea")
				end,
				desc = "New idea",
			},
			{
				"<leader>nk",
				function()
					local title = vim.fn.input("Snippet: ")
					if title == "" then return end
					local lang = vim.fn.input("Language: ")
					require("obsidian.actions").new_from_template("snippets/" .. title, "snippet", function(note)
						note:open({ sync = true })
						if lang ~= "" then
							vim.schedule(function()
								-- Fill language in frontmatter and code fence
								local buf = vim.api.nvim_get_current_buf()
								local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
								for i, line in ipairs(lines) do
									if line:match("^language:") then
										lines[i] = "language: " .. lang
									elseif line == "```" and not lines[i - 1]:match("^```") then
										lines[i] = "```" .. lang
										break
									end
								end
								vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
							end)
						end
					end)
				end,
				desc = "New snippet",
			},
			{
				"<leader>np",
				function()
					local title = vim.fn.input("Project: ")
					if title == "" then return end
					require("obsidian.actions").new_from_template("work/projects/" .. title, "project")
				end,
				desc = "New project note",
			},

			-- Snippet search
			{
				"<leader>nf",
				function() require("utils.obsidian-snippets").find_and_yank() end,
				desc = "Find snippet (yank code)",
			},
			{
				"<leader>nF",
				function() require("utils.obsidian-snippets").search() end,
				desc = "Search snippets (grep)",
			},

			-- Search & navigation
			{ "<leader>ns", "<Cmd>Obsidian search<CR>", desc = "Search" },
			{ "<leader>nb", "<Cmd>Obsidian backlinks<CR>", desc = "Backlinks" },
			{ "<leader>nl", "<Cmd>Obsidian links<CR>", desc = "Links" },
			{ "<leader>nt", "<Cmd>Obsidian template<CR>", desc = "Insert template" },
			{ "<leader>nn", "<Cmd>Obsidian new<CR>", desc = "New note" },
			{ "<leader>no", "<Cmd>Obsidian open<CR>", desc = "Open in app" },
			{ "<leader>nT", "<Cmd>Obsidian tags<CR>", desc = "Search by tag" },
		},
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			workspaces = { { name = "personal", path = "~/obsidian" } },
			legacy_commands = false,

			daily_notes = {
				folder = "work/daily",
				date_format = "%Y-%m-%d",
				template = "work-daily",
				default_tags = { "daily", "work" },
			},

			templates = {
				folder = "templates",
				date_format = "%Y-%m-%d",
				time_format = "%H:%M",
			},

			note_id_func = function(title)
				if title then
					return title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
				end
				return tostring(os.time())
			end,

			attachments = { folder = "assets" },

			new_notes_location = "notes_subdir",
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
			{
				"<leader>gv",
				function()
					local lib = require("diffview.lib")
					if lib.get_current_view() then
						vim.cmd("DiffviewClose")
					else
						vim.cmd("DiffviewOpen")
					end
				end,
				desc = "Diffview toggle",
			},
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
		opts = {
			transient = true,
		},
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

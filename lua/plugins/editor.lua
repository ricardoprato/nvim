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

	-- Diffview surface owned here:
	--   <leader>gd  Diffview working-tree (bare :DiffviewOpen → vs index/HEAD)
	--                 Toggle-close if a view exists in the current tab; otherwise
	--                 opens the full-window file panel listing every uncommitted
	--                 change (modified / staged / deleted / untracked) with
	--                 side-by-side diff. Replaces the prior Snacks.picker.git_diff
	--                 floating hunks list (mini.diff inline overlay <leader>og
	--                 already covers per-buffer hunks).
	--   <leader>gv  Diffview (context-branched single key)
	--                 1) toggle-close if a view exists in the current tab
	--                 2) conflict-mode :DiffviewOpen when summary.in_progress
	--                    substring-matches merge|rebase|cherry-pick|revert
	--                 3) rev-range prompt via vim.ui.input (default HEAD~1..HEAD;
	--                    empty input is a no-op — guards against working-tree default)
	-- Owned elsewhere:
	--   <leader>og                   mini.diff buffer overlay vs HEAD (lua/plugins/mini.lua)
	--   <leader>gl/gL                Snacks.picker.git_log repo + buffer (lua/plugins/snacks.lua)
	--   <leader>gs                   Snacks.picker.git_status file list (lua/plugins/snacks.lua)
	-- No autocmd-driven auto-detect or auto-prompt: conflict markers are visible via
	-- mini.diff overlay + ⚠N statusline; user invokes <leader>gv when ready.
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose" },
		keys = {
			{
				"<leader>gd",
				function()
					local lib = require("diffview.lib")
					if lib.get_current_view() then
						vim.cmd("DiffviewClose")
					else
						vim.cmd("DiffviewOpen")
					end
				end,
				desc = "Diffview working-tree (all uncommitted)",
			},
			{
				"<leader>gv",
				function()
					local lib = require("diffview.lib")
					-- Branch 1: toggle-close if a view is open in the current tab.
					if lib.get_current_view() then
						vim.cmd("DiffviewClose")
						return
					end
					-- Branch 2: conflict-mode trigger. mini.git summary.in_progress
					-- canonical strings (verified): bisect, cherry-pick, merge, revert,
					-- apply (rebase-apply), rebase (rebase-merge). Multiple may be
					-- comma-joined (e.g. "merge,rebase" when a rebase hits a conflict),
					-- so substring-match each candidate rather than equality.
					-- Trigger Diffview only on operations that produce 3-way conflict
					-- markers; bisect + apply are deliberately excluded.
					local summary = vim.b.minigit_summary
					local in_progress = summary and summary.in_progress or ""
					local triggers_3way = in_progress:match("merge")
						or in_progress:match("rebase")
						or in_progress:match("cherry%-pick")
						or in_progress:match("revert")
					if triggers_3way then
						vim.cmd("DiffviewOpen")
						return
					end
					-- Branch 3: rev-range prompt. Empty input is a no-op so the
					-- prompt can't accidentally fall through to bare :DiffviewOpen
					-- (which would default to working-tree vs index).
					vim.ui.input(
						{ prompt = "Diffview rev-range: ", default = "HEAD~1..HEAD" },
						function(input)
							if input and input ~= "" then
								vim.cmd("DiffviewOpen " .. input)
							end
						end
					)
				end,
				desc = "Diffview (toggle / conflict / range)",
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

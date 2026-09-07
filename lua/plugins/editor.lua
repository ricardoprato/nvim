-- Small editing plugins that don't warrant a file of their own. The three that
-- did were split out: obsidian.lua, diffview.lua and kulala.lua.

return {
	-- Render Markdown. No opts: file_types defaults to { "markdown" } already, and
	-- the plugin self-registers from its own plugin/ file, so there is nothing to
	-- pass. Configure via vim.g.render_markdown_config if that ever changes.
	{ "MeanderingProgrammer/render-markdown.nvim", ft = "markdown" },

	-- Grug-far (search & replace)
	{
		"MagicDuck/grug-far.nvim",
		cmd = "GrugFar",
		keys = {
			{ "<leader>rr", "<Cmd>GrugFar<CR>", desc = "Search & Replace" },
			{
				"<leader>rw",
				function()
					-- --fixed-strings: <cword> is a literal, and in filetypes whose
					-- iskeyword covers '.' or '-' it would otherwise reach rg as a
					-- regex. Toggle it off inside the buffer if you want a pattern.
					require("grug-far").open({
						prefills = { search = vim.fn.expand("<cword>"), flags = "--fixed-strings" },
					})
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
}

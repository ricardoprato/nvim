return {
	"stevearc/oil.nvim",
	---@module 'oil'
	---@type oil.SetupOpts
	opts = {
		delete_to_trash = true,
		skip_confirm_for_simple_edits = false,
		view_options = {
			show_hidden = true,
			natural_order = true,
		},
		columns = { "icon", "permissions", "size", "mtime" },
		float = {
			padding = 2,
			max_width = 100,
			max_height = 30,
		},
		keymaps = {
			["<C-p>"] = { "actions.preview", mode = "n" },
			["gd"] = { "actions.toggle_hidden", mode = "n" },
			["g?"] = { "actions.show_help", mode = "n" },
		},
	},
	-- lazy = false required so oil takes over directory buffers from netrw at startup
	-- (netrw is already disabled in init.lua:36-39).
	lazy = false,
	keys = {
		{ "-", function() require("oil").open() end, desc = "Open parent dir (oil)" },
		{ "_", function() require("oil").open_float() end, desc = "Open oil (float)" },
		-- Trash view: `:Oil --trash` (infrequent op, no keymap to keep <leader>o namespace clean)
	},
}

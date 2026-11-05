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
		-- Unified close: `q` and `<Esc>` both call actions.close, which DTRT for
		-- split (restore prior buffer) and float (close window) without leaking
		-- the oil buffer like `<leader>bd` does.
		keymaps = {
			["q"] = { "actions.close", mode = "n" },
			["<Esc>"] = { "actions.close", mode = "n" },
			["<C-p>"] = { "actions.preview", mode = "n" },
			["gd"] = { "actions.toggle_hidden", mode = "n" },
			["g?"] = { "actions.show_help", mode = "n" },
		},
	},
	-- lazy = false required so oil takes over directory buffers from netrw at startup
	-- (netrw is already disabled in init.lua:36-39).
	lazy = false,
	keys = {
		-- Both mappings float. `-` opens the current file's dir (module-level quick
		-- edit); `_` opens the cwd (project root, which auto_root anchors to the
		-- client .git repo). Change cwd from inside oil with the default `` ` ``
		-- (actions.cd), which use_default_keymaps keeps active.
		{ "-", function() require("oil").open_float() end, desc = "Oil float (file dir)" },
		{ "_", function() require("oil").open_float(vim.fn.getcwd()) end, desc = "Oil float (cwd)" },
		-- auto_root narrows cwd to the client repo, so `_` never reaches the
		-- launch dir (~/odoo/<ver>) that holds the other repos of the workspace.
		{ "<leader>ew", function() require("oil").open_float(_G.Config.initial_cwd) end, desc = "Oil float (workspace)" },
		-- Trash view: `:Oil --trash` (infrequent op, no keymap to keep <leader>o namespace clean)
	},
}

return {
	"stevearc/oil.nvim",
	---@module 'oil'
	---@type oil.SetupOpts
	opts = {
		delete_to_trash = true,
	},
	-- lazy = false required so oil takes over directory buffers from netrw at startup
	-- (netrw is already disabled in init.lua:36-39).
	lazy = false,
	keys = {
		{ "-", function() require("oil").open() end, desc = "Open parent dir (oil)" },
	},
}

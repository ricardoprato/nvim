return {
	"folke/todo-comments.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	event = { "BufReadPost", "BufNewFile" },
	opts = {},
	keys = {
		{ "<leader>st", function() Snacks.picker.todo_comments() end, desc = "Todo (Snacks)" },
		{ "<leader>sT", function() Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } }) end, desc = "Todo/Fix/Fixme (Snacks)" },
	},
}

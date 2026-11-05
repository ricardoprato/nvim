return {
	"coder/claudecode.nvim",
	dependencies = { "folke/snacks.nvim" },
	cmd = {
		"ClaudeCode",
		"ClaudeCodeFocus",
		"ClaudeCodeSend",
		"ClaudeCodeAdd",
		"ClaudeCodeTreeAdd",
		"ClaudeCodeDiffAccept",
		"ClaudeCodeDiffDeny",
		"ClaudeCodeSelectModel",
	},
	keys = {
		{ "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
		{ "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
		{ "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
		{ "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
		{ "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
		-- Diffview-aware wrappers: inside a Diffview view the buffer name is a
		-- synthetic `diffview://` URI that claudecode rejects as unreadable, so
		-- utils.claude-diff resolves the real path first. Outside Diffview these
		-- fall straight through to the stock commands.
		{
			"<leader>ab",
			function()
				require("utils.claude-diff").add_buffer()
			end,
			desc = "Add current buffer",
		},
		{
			"<leader>as",
			function()
				require("utils.claude-diff").send_visual()
			end,
			mode = "v",
			desc = "Send to Claude",
		},
		{
			"<leader>as",
			"<cmd>ClaudeCodeTreeAdd<cr>",
			desc = "Add file",
			ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw", "snacks_explorer" },
		},
		-- Diff management
		{ "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
		{ "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
	},
	opts = {
		terminal = {
			split_side = "right",
			split_width_percentage = 0.50,
			snacks_win_opts = {
				wo = {
					signcolumn = "no",
					number = false,
					relativenumber = false,
					statuscolumn = "",
					wrap = false,
					list = false,
				},
				bo = { scrollback = 100000 },
				keys = {
					claude_hide = {
						"<C-,>",
						function(self)
							self:hide()
						end,
						mode = "t",
						desc = "Hide Claude",
					},
				},
			},
		},
		diff_opts = {
			layout = "vertical",
			open_in_new_tab = false,
			hide_terminal_in_new_tab = true,
			auto_close_on_accept = true,
			show_diff_stats = true,
		},
	},
}

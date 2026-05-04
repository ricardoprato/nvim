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
		-- <leader>ac      → singleton (v1.0 path: starts WebSocket + opens float).
		-- 2<leader>ac, 3… → spawn extra anonymous Claude floats sharing the
		--                   singleton's WebSocket port (so @-mention still works
		--                   in the extras as long as the singleton is running).
		--
		-- Pitfall 13 known limitation (spike-test 2026-05-03 verdict = FAIL):
		-- the WebSocket server is bound to the cwd it FIRST started in. After
		-- <leader>sp swaps cwd, @-mention still resolves against the original
		-- project. Workaround: :Lazy reload claudecode.nvim to re-init.
		{
			"<leader>ac",
			function()
				local count = vim.v.count1
				if count == 1 then
					vim.cmd("ClaudeCode")
					return
				end
				local env = {}
				local ok, server = pcall(require, "claudecode.server.init")
				if ok and server and server.state and server.state.port then
					env.CLAUDE_CODE_SSE_PORT = tostring(server.state.port)
				end
				Snacks.terminal.open("claude", {
					cwd = vim.fn.getcwd(),
					env = env,
					count = 1000 + count,
					bo = { bufhidden = "hide" },
					win = {
						position = "float",
						width = 0.95,
						height = 0.95,
						border = "rounded",
						title = " Claude #" .. count .. " ",
						keys = {
							claude_extra_hide = {
								"<C-,>",
								function(self)
									self:hide()
								end,
								mode = "t",
								desc = "Hide Claude",
							},
						},
					},
					start_insert = true,
				})
			end,
			desc = "Toggle Claude (count: extra instance)",
		},
		{ "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
		{ "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
		{ "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
		{ "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
		{ "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
		{ "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
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
			snacks_win_opts = {
				position = "float",
				width = 0.95,
				height = 0.95,
				border = "rounded",
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
			open_in_new_tab = true,
			hide_terminal_in_new_tab = true,
		},
	},
}

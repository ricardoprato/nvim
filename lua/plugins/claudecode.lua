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
	-- WHEN BUMPING claudecode.nvim IN lazy-lock.json:
	--   1. Spawn an agent via <leader>aN, type a name. Inside the float, type @
	--      followed by 1-2 chars of a real cwd file — completion popup must appear.
	--   2. If the popup is missing, the safe_call shim in lua/utils/multi-claude.lua
	--      is broken (upstream renamed claudecode.server.init.state.port). Fix
	--      get_sse_port() in that file. See "WHEN BUMPING" comment block at top.
	--   3. Run :KeymapAudit — must report zero unintended collisions on <leader>a*.
	keys = {
		{ "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
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
		-- Multi-session wrapper (Phase 5; D-01..D-05). Every entry routes to
		-- lua/utils/multi-claude.lua. <leader>a group already declared in
		-- lua/plugins/which-key.lua:8; per-row desc strings are sufficient.
		{
			"<leader>aN",
			function()
				vim.ui.input({ prompt = "Agent name: " }, function(name)
					if name and name ~= "" then
						require("utils.multi-claude").create(name)
					end
				end)
			end,
			desc = "New agent (Claude session)",
		},
		{
			"<leader>al",
			function()
				require("utils.multi-claude").picker()
			end,
			desc = "List agents",
		},
		{
			"<leader>aS",
			function()
				require("utils.multi-claude").switch_mru()
			end,
			desc = "Switch agent (MRU)",
		},
		{
			"<leader>aR",
			function()
				vim.ui.input({ prompt = "Rename agent to: " }, function(new_name)
					if new_name and new_name ~= "" then
						require("utils.multi-claude").rename_current(new_name)
					end
				end)
			end,
			desc = "Rename agent",
		},
		{
			"<leader>aD",
			function()
				require("utils.multi-claude").close_current()
			end,
			desc = "Close agent",
		},
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

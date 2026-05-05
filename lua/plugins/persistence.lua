return {
	"folke/persistence.nvim",
	event = "BufReadPre",
	opts = {
		branch = true, -- per-branch session keying
	},
	keys = {
		{ "<leader>ss", function() require("persistence").select() end, desc = "Select session" },
		{ "<leader>sr", function() require("persistence").load() end, desc = "Restore (cwd)" },
		{ "<leader>sl", function() require("persistence").load({ last = true }) end, desc = "Restore last" },
		{ "<leader>sx", function() require("persistence").stop() end, desc = "Stop auto-save" },
	},
	config = function(_, opts)
		require("persistence").setup(opts)

		-- Drop terminal/nofile buffers before session save so they don't pollute the snapshot.
		-- Exception: preserve claudecode floats so the chat survives project swaps and reloads.
		vim.api.nvim_create_autocmd("User", {
			pattern = "PersistenceSavePre",
			callback = function()
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					local bt = vim.bo[buf].buftype
					if bt == "terminal" or bt == "nofile" then
						local name = vim.api.nvim_buf_get_name(buf)
						local ft = vim.bo[buf].filetype
						local is_claude = name:match("ClaudeCode") ~= nil
							or name:match("claudecode") ~= nil
							or (ft == "snacks_terminal" and name:match("claude") ~= nil)
						if not is_claude then
							pcall(vim.api.nvim_buf_delete, buf, { force = true })
						end
					end
				end
			end,
			desc = "Drop terminal/nofile buffers before save; preserve claudecode",
		})

		-- Re-fire FileType per restored buffer so LSP, treesitter, and ftplugin wake
		-- without a manual :e. Self-assignment forces a fresh FileType emission even
		-- when the buffer already had the same filetype set during session sourcing.
		vim.api.nvim_create_autocmd("User", {
			pattern = "PersistenceLoadPost",
			callback = function()
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if
						vim.api.nvim_buf_is_loaded(buf)
						and vim.bo[buf].buftype == ""
						and vim.fn.buflisted(buf) == 1
					then
						local ft = vim.bo[buf].filetype
						if ft ~= "" then
							vim.bo[buf].filetype = ft
						end
					end
				end
			end,
			desc = "Re-fire FileType per restored buffer",
		})
	end,
}

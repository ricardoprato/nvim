return {
	"folke/persistence.nvim",
	event = "BufReadPre",
	opts = {
		branch = true, -- NAV-05: per-branch session keying. Same as upstream default but locked here so the contract is checked into code.
	},
	keys = {
		{ "<leader>ss", function() require("persistence").select() end, desc = "Select session" },
		{ "<leader>sr", function() require("persistence").load() end, desc = "Restore (cwd)" },
		{ "<leader>sl", function() require("persistence").load({ last = true }) end, desc = "Restore last" },
		{ "<leader>sx", function() require("persistence").stop() end, desc = "Stop auto-save" },
	},
	config = function(_, opts)
		require("persistence").setup(opts)

		-- Clean terminal and nofile buffers before saving (migrated from mini.sessions hook)
		vim.api.nvim_create_autocmd("User", {
			pattern = "PersistenceSavePre",
			callback = function()
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					local bt = vim.bo[buf].buftype
					if bt == "terminal" or bt == "nofile" then
						pcall(vim.api.nvim_buf_delete, buf, { force = true })
					end
				end
			end,
		})

		-- Re-fire FileType per restored buffer so LSP (after/lsp/*.lua via vim.lsp.start),
		-- treesitter, and ftplugin all wake without a manual :e (NAV-04). Self-assignment
		-- is the canonical pattern — more reliable than `doautocmd FileType` across
		-- NV 0.10..0.13 because it forces a fresh FileType emission even when the
		-- buffer already had the same filetype set during session sourcing.
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
			desc = "Re-fire FileType per restored buffer (NAV-04)",
		})
	end,
}

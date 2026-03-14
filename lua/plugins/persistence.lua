return {
	"folke/persistence.nvim",
	event = "BufReadPre",
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
	end,
}

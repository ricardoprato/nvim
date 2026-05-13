return {
	"Bekaboo/dropbar.nvim",
	event = { "BufReadPost", "BufNewFile" },
	opts = function(_, opts)
		-- nvim 0.13-dev removed/renamed BufModifiedSet; replace the buf events list
		-- wholesale (tbl_deep_extend merges arrays by index, which would duplicate entries).
		opts.bar = opts.bar or {}
		opts.bar.update_events = opts.bar.update_events or {}
		opts.bar.update_events.buf = { "FileChangedShellPost", "TextChanged", "ModeChanged" }
		opts.bar.sources = function(buf, _)
			local sources = require("dropbar.sources")
			local utils = require("dropbar.utils")
			if vim.bo[buf].ft == "markdown" then
				return { sources.path, sources.markdown }
			end
			if vim.bo[buf].buftype == "terminal" then
				return { sources.terminal }
			end
			return { sources.path, utils.source.fallback({ sources.lsp, sources.treesitter }) }
		end
		return opts
	end,
	keys = {
		{
			"<leader>lw",
			function()
				require("dropbar.api").pick()
			end,
			desc = "Winbar pick",
		},
	},
}

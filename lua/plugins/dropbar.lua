return {
	"Bekaboo/dropbar.nvim",
	-- TermOpen so the `terminal` source is reachable even when the first buffer
	-- of the session is a terminal (no BufReadPost/BufNewFile fires then).
	event = { "BufReadPost", "BufNewFile", "TermOpen" },
	keys = {
		{
			"<leader>w",
			function()
				require("dropbar.api").pick()
			end,
			desc = "Winbar pick",
		},
	},
}

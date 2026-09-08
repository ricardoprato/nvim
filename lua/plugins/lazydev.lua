return {
	"folke/lazydev.nvim",
	ft = "lua",
	opts = {
		library = {
			-- Load luvit types when the `vim.uv` word is found
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			-- snacks.nvim is only ever reached through its `Snacks` global and is
			-- never `require`d, so lazydev has no call site to resolve it from.
			{ path = "snacks.nvim", words = { "Snacks" } },
		},
	},
}

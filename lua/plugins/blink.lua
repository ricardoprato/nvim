return {
	"saghen/blink.cmp",
	event = { "InsertEnter", "CmdlineEnter" },
	build = function()
		require("blink.cmp").build():wait(60000)
	end,
	dependencies = { "rafamadriz/friendly-snippets", "saghen/blink.lib" },
	config = function()
		require("blink.cmp").setup({
			snippets = { preset = "mini_snippets" },
			fuzzy = { implementation = "rust" },
			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
				-- lazydev.nvim is `ft = "lua"`, so its blink module is only on the
				-- rtp in Lua buffers. Scoping the source keeps every other filetype
				-- from resolving a provider that is not loaded there.
				per_filetype = { lua = { inherit_defaults = true, "lazydev" } },
				providers = {
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						score_offset = 100, -- show at higher priority
					},
				},
			},
		})
		vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
	end,
}

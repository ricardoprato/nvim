return {
	"saghen/blink.cmp",
	event = { "InsertEnter", "CmdlineEnter" },
	build = function()
		-- Tracking `main` means no prebuilt binary: this runs `cargo build --release`,
		-- which routinely exceeds 60s after a bump recompiles deps. A timeout only
		-- kills cargo mid-build; build() already notifies on failure, so wait it out.
		require("blink.cmp").build():wait()
	end,
	dependencies = { "rafamadriz/friendly-snippets", "saghen/blink.lib" },
	opts = {
		snippets = { preset = "mini_snippets" },
		-- Pinned over the default "prefer_rust_with_warning" on purpose: a missing
		-- binary should make setup() error out, not silently degrade to the Lua matcher.
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
					-- lua_ls also completes `vim.*`, but without the plugin-aware types
					-- lazydev injects; the offset makes lazydev's entries win the tie.
					score_offset = 100,
				},
			},
		},
	},
	-- config is needed for the imperative step: every LSP server must receive
	-- blink's capabilities, which only exist once blink.cmp is set up.
	config = function(_, opts)
		require("blink.cmp").setup(opts)
		vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
	end,
}

-- Kulala: HTTP client for .http / .rest files.
-- Keymap surface is kulala's own set, under global_keymaps_prefix = <leader>R.
-- Global, in any buffer:
--   Rs send request   Ra send all   Rr replay last   Rb scratchpad   Ro open UI
-- Buffer-local in http/rest, registered by the plugin's own FileType autocmd:
--   <CR> send                Rn/Rp next/prev request   Rf find request
--   Rt toggle headers/body   Ri inspect                Re select env
--   Rc copy as cURL          RC paste from cURL        Rq close window
--   Rj cookies jar           Ru auth config            RS stats
--   Rx/RX clear globals / cached files                 Rg GraphQL schema
-- Note the plugin remaps plain <CR> inside http buffers.
-- Only Rb/Ro are useful without an .http buffer open, so those two are the
-- lazy trigger (string form: lazy loads, then replays the key into kulala's
-- own mapping — no rhs duplicated here). Canonical list: kulala/config/keymaps.lua.
return {
	"mistweaverco/kulala.nvim",
	ft = { "http", "rest" },
	keys = { "<leader>Rb", "<leader>Ro" },
	opts = {
		-- Kulala curates ~20 keymaps and ft-scopes them; re-declaring that set
		-- here would just drift from upstream.
		global_keymaps = true,
		ui = {
			-- display_mode / icons live under `ui` since the option table was
			-- nested; the flat top-level form still works but is legacy.
			display_mode = "float",
			-- Nerd Font (FA range, same family as the snacks dashboard) instead
			-- of kulala's default emoji: these render as inline virtual text, so
			-- single-width matters for alignment, and a monochrome glyph picks up
			-- loadingHighlight / doneHighlight / errorHighlight from the
			-- colorscheme — an emoji brings its own color and ignores them.
			icons = {
				inlay = {
					loading = "", -- U+F110 nf-fa-spinner
					done = "", -- U+F00C nf-fa-check
					error = "", -- U+F00D nf-fa-close
				},
			},
		},
		-- Body pretty-printing is kulala-core's job now: the old
		-- default_formatters (jq / xmllint) and additional_curl_options keys
		-- no longer exist upstream, they were being silently ignored.
		response_format = { indent = 2 },
	},
}

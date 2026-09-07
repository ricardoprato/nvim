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
-- Of those five globals only Rb/Ro/Rr do anything without an .http buffer
-- open (Rs/Ra need requests to send), so those three are the lazy trigger and
-- `ft` covers the rest. Canonical list: kulala/config/keymaps.lua.
return {
	"mistweaverco/kulala.nvim",
	ft = { "http", "rest" },
	-- No rhs: lazy creates a placeholder map, loads the plugin on press, then
	-- replays the key into kulala's own mapping — nothing duplicated here. The
	-- desc is only what which-key shows *before* the load; it repeats kulala's
	-- own wording verbatim so the label doesn't shift once the plugin takes over.
	keys = {
		{ "<leader>Rb", desc = "Open scratchpad" },
		{ "<leader>Ro", desc = "Open kulala" },
		{ "<leader>Rr", desc = "Replay the last request" },
	},
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

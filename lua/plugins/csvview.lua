-- csvview: tabular rendering for CSV/TSV, drawn entirely with virtual text.
--
-- The buffer keeps its raw bytes: alignment, borders and the sticky header are
-- extmarks painted on top, so a file stays byte-identical after a session and
-- `:w` never writes back padding. That also means the per-column rainbow from
-- $VIMRUNTIME/syntax/csv.vim survives underneath — see the `syntax_wins` guard
-- in lua/plugins/treesitter.lua, which keeps tree-sitter off csv/tsv so that
-- syntax stays alive (the csv highlights.scm only tags the separator).
--
-- The plugin ships its own async parser, so nothing here depends on a
-- tree-sitter parser being installed.
return {
	"hat0uma/csvview.nvim",
	---@module "csvview"
	---@type CsvView.Options
	opts = {
		view = {
			-- "border" draws `│` between fields instead of merely highlighting
			-- the comma. On an import file the column boundary is the thing you
			-- actually track while scanning, and a glyph reads faster than a
			-- colour shift.
			display_mode = "border",
			-- Both are csvview's own defaults (config.lua:172, :179), pinned so the
			-- sticky header cannot quietly disappear from an import file if upstream
			-- changes its mind: `header_lnum = false` would switch off header
			-- detection and the sticky header together.
			header_lnum = true,
			sticky_header = { enabled = true },
			-- Freeze the leftmost two columns while scrolling right, so the
			-- record stays identifiable (id + name) no matter how far out the
			-- cursor travels. `separator = false` is the default and correct
			-- here: with display_mode = "border" the pinned columns already end
			-- in a `│`, and a separator would double it.
			sticky_columns = { enabled = true, count = 2 },
		},
		-- Field-wise motions and text objects, active only while csvview is on.
		--
		-- `cif` is the reason this block exists: editing a cell stops being
		-- "count commas to the fourth field" and becomes a position-independent
		-- operator. `af` takes the delimiter with it.
		--
		-- <S-Tab>/<S-Enter> need the terminal to disambiguate shifted keys.
		-- Kitty does via its keyboard protocol (see lua/utils/kitty-nav.lua);
		-- a terminal without CSI-u will silently deliver plain <Tab>/<Enter>.
		keymaps = {
			textobject_field_inner = { "if", mode = { "o", "x" } },
			textobject_field_outer = { "af", mode = { "o", "x" } },
			jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
			jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
			jump_next_row = { "<Enter>", mode = { "n", "v" } },
			jump_prev_row = { "<S-Enter>", mode = { "n", "v" } },
		},
	},
	-- `ft` is the lazy trigger; `cmd` keeps the commands reachable for a buffer
	-- that never got a csv/tsv filetype (a pasted scratch buffer, a `.txt`
	-- export) where `:CsvViewEnable delimiter=;` still does the right thing.
	ft = { "csv", "tsv" },
	cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
	config = function(_, opts)
		require("csvview").setup(opts)

		-- The plugin has no auto-enable option, so attach on FileType. Enabling
		-- an already-enabled buffer is a no-op re-apply, which is what makes the
		-- catch-up loop below safe.
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("csvview-attach", { clear = true }),
			pattern = { "csv", "tsv" },
			callback = function(ev)
				require("csvview").enable(ev.buf)
			end,
			desc = "Enable csvview for csv/tsv buffers",
		})

		-- The FileType event that loaded this plugin has already fired, so the
		-- buffer that triggered the load would otherwise sit unrendered until
		-- the next `:e`. Catch up explicitly rather than leaning on lazy.nvim
		-- re-emitting the event.
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			local ft = vim.bo[buf].filetype
			if vim.api.nvim_buf_is_loaded(buf) and (ft == "csv" or ft == "tsv") then
				require("csvview").enable(buf)
			end
		end
	end,
}

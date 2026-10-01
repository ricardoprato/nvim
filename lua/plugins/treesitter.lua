return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		-- Eager: everything below lives in `config` — the parser install and the
		-- FileType callback that attaches them. A lazy trigger would register that
		-- autocmd after the FileType event that should have fired it, so the first
		-- buffer of a session would open unhighlighted and unfolded.
		lazy = false,
		build = ":TSUpdate",
		config = function()
			local ts = require("nvim-treesitter")

			local languages = {
				"lua",
				"vimdoc",
				"markdown",
				"markdown_inline",
				"python",
				"xml",
				"html",
				"css",
				"javascript",
				"typescript",
				"tsx",
				"astro",
				"bash",
				"json",
				"yaml",
				"toml",
				"dockerfile",
				"gitcommit",
				"diff",
				"query",
				"http",
				"regex",
				"gdscript",
				"godot_resource",
				"gdshader",
				"rust",
			}

			-- Install missing parsers (async, but runs early thanks to lazy=false).
			--
			-- `force` is mandatory: `install()` skips any language listed by
			-- `config.get_installed()`, which unions the `parser/` and `queries/`
			-- directories, and `queries/` holds a symlink for every language
			-- nvim-treesitter knows about. Without `force` the call is a silent
			-- no-op. Rebuilding nothing needlessly is still guaranteed because
			-- `missing` already filtered on the real parser files.
			local missing = vim.tbl_filter(function(lang)
				return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0
			end, languages)
			if #missing > 0 then
				ts.install(missing, { force = true })
			end

			-- Function-wise motions, from the `textobjects` queries shipped by
			-- nvim-treesitter-textobjects. Registered buffer-local on purpose:
			-- $VIMRUNTIME/ftplugin/python.vim maps ]m/[m/]M/[M buffer-local, so a
			-- global mapping would lose in the filetype this config uses most. This
			-- autocmd is created after ftplugin.vim's, so it wins the last word.
			--
			-- Suffix choice: mini.bracketed already owns ]f (file) and ]c (comment),
			-- and Snacks.words owns ]]/[[ (references).
			local motions = {
				{ "]m", "goto_next_start", "Next function start" },
				{ "]M", "goto_next_end", "Next function end" },
				{ "[m", "goto_previous_start", "Prev function start" },
				{ "[M", "goto_previous_end", "Prev function end" },
			}

			-- Tree-sitter folds wherever a parser is active. Both options are
			-- window-local and stick when a window switches buffers, so the
			-- parser-less branch has to put 'foldmethod' back to the `indent`
			-- default set in lua/config/options.lua. 'foldexpr' is only read under
			-- `expr`, so it can be set unconditionally. A buffer with no detected
			-- filetype fires no FileType event and so keeps whatever the window
			-- had, which is harmless: `foldexpr` yields 0 with no parser.
			local function set_folds(buf, method)
				for _, win in ipairs(vim.fn.win_findbuf(buf)) do
					vim.api.nvim_set_option_value("foldexpr", "v:lua.vim.treesitter.foldexpr()", { win = win })
					vim.api.nvim_set_option_value("foldmethod", method, { win = win })
				end
			end

			local function on_parser_active(buf)
				set_folds(buf, "expr")
				for _, motion in ipairs(motions) do
					local lhs, goto_fn, desc = motion[1], motion[2], motion[3]
					vim.keymap.set({ "n", "x", "o" }, lhs, function()
						require("nvim-treesitter-textobjects.move")[goto_fn]("@function.outer", "textobjects")
					end, { buffer = buf, desc = desc })
				end
			end

			local group = vim.api.nvim_create_augroup("treesitter-attach", { clear = true })
			local installing = {}

			-- Filetypes whose bundled Vim syntax beats the tree-sitter queries.
			-- $VIMRUNTIME/syntax/csv.vim paints every column its own colour through
			-- csvCol1..csvCol8, while the csv/tsv highlights.scm only tags the
			-- separator. `vim.treesitter.start` turns regex syntax off, so letting a
			-- parser attach here is a strict downgrade -- and skipping the callback
			-- outright also stops the on-demand installer from fetching it.
			local syntax_wins = { csv = true, tsv = true }

			-- Enable highlighting and auto-install missing parsers on FileType
			vim.api.nvim_create_autocmd("FileType", {
				group = group,
				callback = function(ev)
					if syntax_wins[ev.match] then
						set_folds(ev.buf, "indent")
						return
					end
					if pcall(vim.treesitter.start, ev.buf) then
						on_parser_active(ev.buf)
						return
					end
					set_folds(ev.buf, "indent")
					-- Parser not installed — install on-demand (once per lang per session)
					local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
					if installing[lang] then
						return
					end
					if not vim.list_contains(ts.get_available(), lang) then
						return
					end
					installing[lang] = true
					vim.notify("Installing treesitter parser: " .. lang, vim.log.levels.INFO)
					ts.install(lang, { force = true }):await(function(err, ok)
						-- Cleared either way so a failed download can be retried
						installing[lang] = nil
						-- `install()` reports a failed download by returning false
						-- (install.lua:541, `done == #tasks`); `err` is only set for a
						-- raised Lua error, so checking it alone stays silent for the
						-- case that actually happens — no tree-sitter CLI, no compiler,
						-- no network — after the INFO above promised an install.
						--
						-- The notify is scheduled because install() only calls
						-- `a.schedule()` for `#languages > 1` (install.lua:531), so this
						-- single-language callback can resume inside a libuv callback,
						-- where nvim_echo raises E5560.
						if err or not ok then
							vim.schedule(function()
								vim.notify(
									("Failed to install treesitter parser: %s"):format(lang),
									vim.log.levels.WARN
								)
							end)
							return
						end
						vim.schedule(function()
							if vim.api.nvim_buf_is_valid(ev.buf) and pcall(vim.treesitter.start, ev.buf) then
								on_parser_active(ev.buf)
							end
						end)
					end)
				end,
				desc = "Start tree-sitter highlighting and folds (auto-install missing parsers)",
			})
		end,
	},
	{
		-- Query provider: `queries/<lang>/textobjects.scm` backs both the ]m/[m
		-- motions above and the mini.ai specs in lua/plugins/mini.lua.
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		event = { "BufReadPost", "BufNewFile" },
	},
}

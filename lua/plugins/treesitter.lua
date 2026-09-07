return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
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

			local group = vim.api.nvim_create_augroup("treesitter-attach", { clear = true })
			local installing = {}

			-- Enable highlighting and auto-install missing parsers on FileType
			vim.api.nvim_create_autocmd("FileType", {
				group = group,
				callback = function(ev)
					if pcall(vim.treesitter.start, ev.buf) then
						return
					end
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
					ts.install(lang, { force = true }):await(function(err)
						-- Cleared either way so a failed download can be retried
						installing[lang] = nil
						if err then
							return
						end
						vim.schedule(function()
							if vim.api.nvim_buf_is_valid(ev.buf) then
								pcall(vim.treesitter.start, ev.buf)
							end
						end)
					end)
				end,
				desc = "Start tree-sitter highlighting (auto-install missing parsers)",
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		event = { "BufReadPost", "BufNewFile" },
	},
}

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		config = function()
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
				"jsx",
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

			-- Install missing parsers (async, but runs early thanks to lazy=false)
			local missing = vim.tbl_filter(function(lang)
				return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0
			end, languages)
			if #missing > 0 then
				require("nvim-treesitter").install(missing)
			end

			-- Enable highlighting and auto-install missing parsers on FileType
			local installing = {}
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(ev)
					local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
					if pcall(vim.treesitter.start, ev.buf) then
						return
					end
					-- Parser not installed — install on-demand (once per lang per session)
					if installing[lang] then
						return
					end
					local available = require("nvim-treesitter").get_available()
					if not vim.list_contains(available, lang) then
						return
					end
					installing[lang] = true
					vim.notify("Installing treesitter parser: " .. lang, vim.log.levels.INFO)
					require("nvim-treesitter").install(lang)
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

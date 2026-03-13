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
			}

			-- Install missing parsers (async, but runs early thanks to lazy=false)
			local missing = vim.tbl_filter(function(lang)
				return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0
			end, languages)
			if #missing > 0 then
				require("nvim-treesitter").install(missing)
			end

			-- Enable highlighting via FileType — registered before any buffer needs it
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(ev)
					pcall(vim.treesitter.start, ev.buf)
				end,
				desc = "Start tree-sitter highlighting",
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		event = { "BufReadPost", "BufNewFile" },
	},
}

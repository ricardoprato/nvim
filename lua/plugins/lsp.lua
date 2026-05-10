return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPost", "BufNewFile" },
		keys = {
			{ "<leader>la", function() vim.lsp.buf.code_action() end, desc = "Actions" },
			{ "<leader>ld", function() vim.diagnostic.open_float() end, desc = "Diagnostic popup" },
			{ "<leader>li", function() vim.lsp.buf.implementation() end, desc = "Implementation" },
			{ "<leader>lh", function() vim.lsp.buf.hover() end, desc = "Hover" },
			{ "<leader>lr", function() vim.lsp.buf.rename() end, desc = "Rename" },
			{ "<leader>lR", function() vim.lsp.buf.references() end, desc = "References" },
			{ "<leader>ls", function() vim.lsp.buf.definition() end, desc = "Source definition" },
			{ "<leader>lt", function() vim.lsp.buf.type_definition() end, desc = "Type definition" },
		},
		config = function()
			vim.lsp.enable({
				"lua_ls",
				"pyright",
				"odoo_lsp",
				"ts_ls",
				"eslint",
				"denols",
				"jsonls",
				"yamlls",
				"lemminx",
				"astro",
			})

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("lsp_attach_keymaps", { clear = true }),
				callback = function(args)
					vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = args.buf, desc = "LSP Hover" })
				end,
			})
		end,
	},
	{ "b0o/SchemaStore.nvim", lazy = true },
	{
		"mason-org/mason.nvim",
		cmd = "Mason",
		event = { "BufReadPost", "BufNewFile" },
		dependencies = {
			"mason-org/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
		},
		config = function()
			require("mason").setup({ PATH = "prepend" })
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"pyright",
					"ts_ls",
					"eslint",
					"denols",
					"jsonls",
					"yamlls",
					"lemminx",
					"astro",
				},
				automatic_installation = true,
			})
			require("mason-tool-installer").setup({
				ensure_installed = {
					"stylua",                                          -- Lua
					"black", "isort", "ruff", "mypy", "debugpy",       -- Python (ruff coexists, NOT replaces)
					"prettier", "prettierd", "eslint_d",               -- JS/TS
					"markdownlint-cli2",                               -- Markdown (closes CONCERNS.md gap)
					"shellcheck", "shfmt",                             -- Shell
					"taplo", "hadolint",                               -- TOML, Dockerfile
				},
				auto_update = true,
			})
		end,
	},
}

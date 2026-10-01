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
				-- Not installed through Mason: the Godot editor itself serves the
				-- language server over TCP (127.0.0.1:6005), so it only attaches while
				-- the project is open in Godot.
				"gdscript",
				"rust_analyzer",
				"tailwindcss",
				-- Only attaches under a .sln/.csproj: in Unity those exist after
				-- "Regenerate project files" (Preferences > External Tools).
				"roslyn_ls",
				-- Uses the system clangd (pacman), not Mason, so it matches the clang
				-- toolchain that builds the code. Unreal needs a compile_commands.json at
				-- the project root: UnrealBuildTool -mode=GenerateClangDatabase.
				"clangd",
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
					-- rustup's rust-analyzer component is not part of the toolchain here;
					-- Mason's binary wins because mason prepends its bin to PATH.
					"rust_analyzer",
					"tailwindcss",
					"roslyn_ls",
				},
				automatic_installation = true,
			})
			require("mason-tool-installer").setup({
				-- Solo herramientas con consumidor real (conform o dap).
				-- Los LSP se instalan via mason-lspconfig, no aca.
				ensure_installed = {
					"stylua", -- Lua (conform)
					"ruff", -- Python: organize_imports + format (conform)
					"debugpy", -- Python: debugger (dap)
					"prettierd", -- JS/TS/JSON/YAML/HTML/CSS/MD (conform)
					"prettier", -- fallback de prettierd
					"shfmt", -- sh/bash (conform)
					"taplo", -- TOML (conform)
					"codelldb", -- Rust: debugger (dap)
					"js-debug-adapter", -- JS/TS: Node and Chrome debugger (dap)
					"csharpier", -- C# (conform)
				},
				auto_update = true,
			})
		end,
	},
}

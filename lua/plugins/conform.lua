-- prettier chain: prettierd (daemon, arranque rapido) con fallback al prettier normal.
-- `extra` permite sumar un ultimo recurso por filetype (ej: deno_fmt en proyectos Deno).
local function prettier(extra)
	local chain = { "prettierd", "prettier" }
	if extra then
		table.insert(chain, extra)
	end
	chain.stop_after_first = true
	return chain
end

return {
	"stevearc/conform.nvim",
	event = "BufWritePre",
	cmd = { "ConformInfo", "FormatToggle" },
	keys = {
		{
			"<leader>lf",
			function()
				require("conform").format({ async = true })
			end,
			mode = { "n", "x" },
			desc = "Format",
		},
		{ "<leader>oF", "<cmd>FormatToggle<cr>", desc = "Toggle autoformat (global)" },
		{ "<leader>of", "<cmd>FormatToggle!<cr>", desc = "Toggle autoformat (buffer)" },
	},
	config = function()
		vim.api.nvim_create_user_command("FormatToggle", function(args)
			if args.bang then
				vim.b.disable_autoformat = not vim.b.disable_autoformat
				vim.notify("Autoformat (buffer): " .. (vim.b.disable_autoformat and "OFF" or "ON"))
			else
				vim.g.disable_autoformat = not vim.g.disable_autoformat
				vim.notify("Autoformat (global): " .. (vim.g.disable_autoformat and "OFF" or "ON"))
			end
		end, { desc = "Toggle autoformat (use ! for buffer-only)", bang = true })

		require("conform").setup({
			-- Fail fast: si un formatter revienta, quiero enterarme.
			-- notify_no_formatters queda en false porque "este ft no tiene formatter"
			-- es ruido, no un error.
			notify_on_error = true,
			notify_no_formatters = false,
			-- Aplica al <leader>lf manual; el save lo pisa con lsp_format = "never".
			default_format_opts = {
				lsp_format = "fallback",
			},
			format_on_save = function(bufnr)
				if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
					return
				end
				return { timeout_ms = 2000, lsp_format = "never" }
			end,
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_organize_imports", "ruff_format" },

				javascript = prettier("deno_fmt"),
				typescript = prettier("deno_fmt"),
				javascriptreact = prettier("deno_fmt"),
				typescriptreact = prettier("deno_fmt"),
				json = prettier("deno_fmt"),
				jsonc = prettier("deno_fmt"),
				yaml = prettier(),
				html = prettier(),
				css = prettier(),
				scss = prettier(),
				-- injected formatea los bloques de codigo embebidos en el markdown.
				markdown = { "prettierd", "injected" },

				sh = { "shfmt" },
				bash = { "shfmt" },
				toml = { "taplo" },
				-- rustfmt ships with the toolchain, so it reads the project's
				-- rustfmt.toml and edition from Cargo.toml like `cargo fmt` does.
				rust = { "rustfmt" },
				cs = { "csharpier" },

				-- Filetypes sin formatter propio.
				["_"] = { "trim_whitespace" },
			},
		})
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}

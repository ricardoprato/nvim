return {
	"stevearc/conform.nvim",
	event = "BufWritePost",
	cmd = "ConformInfo",
	keys = {
		{
			"<leader>lf",
			function()
				require("conform").format({ lsp_fallback = true })
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
			notify_on_error = false,
			format_after_save = function(bufnr)
				if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
					return
				end
				return { timeout_ms = 2000, lsp_format = "never" }
			end,
			formatters = {
				black = { prepend_args = { "--fast" } },
			},
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "isort", "black" },
				javascript = { "prettier", "deno_fmt", stop_after_first = true },
				typescript = { "prettier", "deno_fmt", stop_after_first = true },
				javascriptreact = { "prettier", "deno_fmt", stop_after_first = true },
				typescriptreact = { "prettier", "deno_fmt", stop_after_first = true },
				json = { "prettier", "deno_fmt", stop_after_first = true },
				yaml = { "prettier" },
				xml = { "xmlformatter" },
			},
		})
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}

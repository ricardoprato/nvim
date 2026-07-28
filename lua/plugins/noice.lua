return {
	"folke/noice.nvim",
	event = "VeryLazy",
	dependencies = { "MunifTanjim/nui.nvim" },
	opts = {
		lsp = {
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				["vim.lsp.util.stylize_markdown"] = true,
				["cmp.entry.get_documentation"] = true,
			},
			-- LSP progress disabled: pyright re-analyzes the huge Odoo workspace
			-- on every change, and each progress toast opening/closing triggered
			-- the WinClosed `mode` redraw below, flickering every dropbar winbar
			-- (the .py breadcrumb and the claudecode terminal breadcrumb).
			progress = { enabled = false },
		},
		presets = {
			bottom_search = true,
			command_palette = true,
			long_message_to_split = true,
			inc_rename = false,
			lsp_doc_border = true,
		},
		routes = {
			-- Hide "written" messages
			{
				filter = { event = "msg_show", kind = "", find = "written" },
				opts = { skip = true },
			},
		},
		views = {
			notify = {
				replace = true,
				merge = true,
			},
		},
	},
	config = function(_, opts)
		require("noice").setup(opts)
		-- Safety net: when any noice float closes, force a redraw so terminal
		-- buffers (claudecode) don't show stale rows where the overlay sat.
		local grp = vim.api.nvim_create_augroup("noice-terminal-redraw", { clear = true })
		vim.api.nvim_create_autocmd("WinClosed", {
			group = grp,
			callback = function(args)
				local win = tonumber(args.match)
				if not win or not vim.api.nvim_win_is_valid(win) then
					return
				end
				local buf = vim.api.nvim_win_get_buf(win)
				local ft = vim.bo[buf].filetype or ""
				if ft:match("^noice") then
					-- Defer so the close completes before the redraw call.
					vim.schedule(function()
						vim.cmd("mode")
					end)
				end
			end,
			desc = "Redraw after noice float closes (fixes claude terminal stale rows)",
		})
	end,
}

return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	config = function()
		-- Custom component: git branch + ahead/behind + conflicts
		local function git_status()
			local summary = vim.b.minigit_summary_string
			if summary and summary ~= "" then
				return summary
			end
			return ""
		end

		-- Custom component: LSP progress in the statusline (replaces the noisy
		-- progress toast that flickered every winbar — see noice.lua). Driven by
		-- the LspProgress autocmd; refresh() repaints only the statusline, never
		-- the whole screen, so dropbar breadcrumbs stay put.
		local lsp_progress_state = {} -- [client_name] = "title message 42%"
		local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

		vim.api.nvim_create_autocmd("LspProgress", {
			group = vim.api.nvim_create_augroup("lualine-lsp-progress", { clear = true }),
			pattern = { "begin", "report", "end" },
			callback = function(args)
				local value = args.data and args.data.params and args.data.params.value
				if type(value) ~= "table" then
					return
				end
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				local name = client and client.name or "lsp"
				if value.kind == "end" then
					lsp_progress_state[name] = nil
				else
					local parts = {}
					if value.title and value.title ~= "" then
						table.insert(parts, value.title)
					end
					if value.message and value.message ~= "" then
						table.insert(parts, value.message)
					end
					if value.percentage then
						table.insert(parts, string.format("%d%%", value.percentage))
					end
					lsp_progress_state[name] = table.concat(parts, " ")
				end
				require("lualine").refresh()
			end,
		})

		local function lsp_progress()
			local active = {}
			for name, text in pairs(lsp_progress_state) do
				table.insert(active, text ~= "" and (name .. ": " .. text) or name)
			end
			if #active == 0 then
				return ""
			end
			local frame = spinner_frames[(math.floor(vim.uv.hrtime() / 1e8) % #spinner_frames) + 1]
			return frame .. " " .. table.concat(active, " | ")
		end

		require("lualine").setup({
			options = {
				theme = "auto",
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				globalstatus = true,
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = {
					{ git_status, icon = "" },
					"diagnostics",
				},
				lualine_c = { { "filename", path = 1 }, { lsp_progress } },
				lualine_x = { "encoding", "fileformat", "filetype" },
				lualine_y = { "progress" },
				lualine_z = { "location", "searchcount" },
			},
		})
	end,
}

return {
	"echasnovski/mini.nvim",
	lazy = false,
	priority = 900,
	keys = {
		-- Git (mini.git + mini.diff)
		{ "<leader>gc", "<Cmd>Git commit<CR>", desc = "Commit" },
		{ "<leader>gC", "<Cmd>Git commit --amend<CR>", desc = "Commit amend" },
		{ "<leader>og", "<Cmd>lua MiniDiff.toggle_overlay()<CR>", desc = "Toggle overlay" },
		{ "<leader>gP", "<Cmd>Git push<CR>", desc = "Git push" },
		{ "<leader>gp", "<Cmd>Git pull --rebase<CR>", desc = "Git pull" },
		{ "<leader>g-", "<Cmd>Git checkout -<CR>", desc = "Git checkout -" },

		-- Visits (mini.visits)
		{ "<leader>vv", '<Cmd>lua MiniVisits.add_label("core")<CR>', desc = 'Add "core" label' },
		{ "<leader>vV", '<Cmd>lua MiniVisits.remove_label("core")<CR>', desc = 'Remove "core" label' },
		{ "<leader>vl", "<Cmd>lua MiniVisits.add_label()<CR>", desc = "Add label" },
		{ "<leader>vL", "<Cmd>lua MiniVisits.remove_label()<CR>", desc = "Remove label" },

		-- Other (mini.misc, mini.trailspace)
		{ "<leader>or", "<Cmd>lua MiniMisc.resize_window()<CR>", desc = "Resize to default width" },
		{ "<leader>ot", "<Cmd>lua MiniTrailspace.trim()<CR>", desc = "Trim trailspace" },
	},
	config = function()
		-- Step 1: modules needed for first draw ================================

		require("mini.basics").setup({
			options = { basic = false },
			mappings = { windows = false, move_with_alt = true },
		})

		-- Icons + nvim-web-devicons mock
		local ext3_blocklist = { scm = true, txt = true, yml = true }
		local ext4_blocklist = { json = true, yaml = true }
		require("mini.icons").setup({
			use_file_extension = function(ext, _)
				return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
			end,
		})
		vim.schedule(function()
			MiniIcons.mock_nvim_web_devicons()
			MiniIcons.tweak_lsp_kind()
		end)

		require("mini.misc").setup()
		MiniMisc.setup_auto_root()
		MiniMisc.setup_restore_cursor()
		MiniMisc.setup_termbg_sync()

		-- Step 2: deferred modules =============================================

		vim.schedule(function()
			local ai = require("mini.ai")
			ai.setup({
				custom_textobjects = {
					F = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
				},
				search_method = "cover",
			})

			require("mini.align").setup()
			require("mini.bracketed").setup()

			require("mini.comment").setup()
			require("mini.diff").setup()

			-- Git
			require("mini.git").setup()

			local format_summary = function(data)
				local summary = vim.b[data.buf].minigit_summary
				if not summary then
					return
				end
				local parts = {}
				if summary.head_name then
					table.insert(parts, summary.head_name)
				end
				local git_utils = require("utils.git")
				local status = git_utils.get_ahead_behind()
				if status.ahead > 0 then
					table.insert(parts, "↑" .. status.ahead)
				end
				if status.behind > 0 then
					table.insert(parts, "↓" .. status.behind)
				end
				if summary.in_progress and summary.in_progress ~= "" then
					table.insert(parts, "[" .. summary.in_progress .. "]")
				end
				local conflicts = git_utils.count_conflicts(data.buf)
				if conflicts > 0 then
					table.insert(parts, "⚠" .. conflicts)
				end
				if summary.status then
					table.insert(parts, summary.status)
				end
				vim.b[data.buf].minigit_summary_string = table.concat(parts, " ")
			end

			_G.Config.new_autocmd("User", "MiniGitUpdated", format_summary, "Format git summary")
			_G.Config.new_autocmd("User", "MiniGitUpdated", function()
				require("utils.git").invalidate_cache()
			end, "Invalidate git status cache")
			_G.Config.new_autocmd("User", "MiniGitUpdated", function()
				local git = require("utils.git")
				if not git._fetch_timer then
					git.start_auto_fetch(1)
				end
			end, "Start background git fetch")

			-- Hipatterns
			local hipatterns = require("mini.hipatterns")
			hipatterns.setup({
				highlighters = {
					fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
					hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
					todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
					note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
					hex_color = hipatterns.gen_highlighter.hex_color(),
					tailwind = {
						pattern = function()
							local ft = vim.bo.filetype
							local allowed = {
								"html",
								"css",
								"scss",
								"less",
								"javascript",
								"javascriptreact",
								"typescript",
								"typescriptreact",
								"vue",
								"svelte",
								"astro",
							}
							if not vim.tbl_contains(allowed, ft) then
								return nil
							end
							return "%f[%w:-]()[%w:-]+%-[a-z%-]+%-%d+/?%d*()%f[^%w:-]"
						end,
						group = function(_, _, match_data)
							local match = match_data.full_match
							local color, shade = match:match("[%w-]+%-([a-z%-]+)%-(%d+)")
							shade = tonumber(shade)
							local tw = require("utils.tailwind-colors")
							local bg_hex = vim.tbl_get(tw.colors, color, shade)
							if bg_hex then
								local hl_group = "MiniHipatternsTailwind" .. color .. shade
								if not tw.hl_cache[hl_group] then
									tw.hl_cache[hl_group] = true
									local fg_shade = shade == 500 and 950 or shade < 500 and 900 or 100
									local fg_hex = vim.tbl_get(tw.colors, color, fg_shade)
									vim.api.nvim_set_hl(0, hl_group, { bg = "#" .. bg_hex, fg = "#" .. fg_hex })
								end
								return hl_group
							end
						end,
						extmark_opts = { priority = 2000 },
					},
					git_conflict_start = { pattern = "^<<<<<<< .*", group = "DiffDelete" },
					git_conflict_sep = { pattern = "^=======", group = "DiffChange" },
					git_conflict_end = { pattern = "^>>>>>>> .*", group = "DiffAdd" },
				},
			})

			require("mini.jump").setup()
			require("mini.jump2d").setup()

			require("mini.keymap").setup()
			MiniKeymap.map_multistep("i", "<CR>", { "minipairs_cr" })
			MiniKeymap.map_multistep("i", "<BS>", { "minipairs_bs" })

			require("mini.move").setup()

			require("mini.operators").setup()
			vim.keymap.set("n", "(", "gxiagxila", { remap = true, desc = "Swap arg left" })
			vim.keymap.set("n", ")", "gxiagxina", { remap = true, desc = "Swap arg right" })

			require("mini.pairs").setup({ modes = { command = true } })

			-- Snippets
			local latex_patterns = { "latex/**/*.json", "**/latex.json" }
			local lang_patterns = {
				tex = latex_patterns,
				plaintex = latex_patterns,
				markdown_inline = { "markdown.json" },
			}
			local snippets = require("mini.snippets")
			local config_path = vim.fn.stdpath("config")
			snippets.setup({
				snippets = {
					snippets.gen_loader.from_file(config_path .. "/snippets/global.json"),
					snippets.gen_loader.from_lang({ lang_patterns = lang_patterns }),
				},
			})
			MiniSnippets.start_lsp_server()

			require("mini.splitjoin").setup()
			require("mini.surround").setup()
			require("mini.trailspace").setup()
			require("mini.visits").setup()
		end) -- end vim.schedule
	end,
}

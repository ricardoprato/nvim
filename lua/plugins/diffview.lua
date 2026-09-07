-- Diffview surface owned here:
--   <leader>gd  Diffview working-tree (bare :DiffviewOpen → vs index/HEAD)
--                 Toggle-close if a view exists in the current tab; otherwise
--                 opens the full-window file panel listing every uncommitted
--                 change (modified / staged / deleted / untracked) with
--                 side-by-side diff. Replaces the prior Snacks.picker.git_diff
--                 floating hunks list (mini.diff inline overlay <leader>og
--                 already covers per-buffer hunks).
--   <leader>gv  Diffview (context-branched single key)
--                 1) toggle-close if a view exists in the current tab
--                 2) conflict-mode :DiffviewOpen when summary.in_progress
--                    substring-matches merge|rebase|cherry-pick|revert
--                 3) rev-range prompt via vim.ui.input (default HEAD~1..HEAD;
--                    empty input is a no-op — guards against working-tree default)
--   <leader>gr  Branch review — <base>...HEAD --imply-local
--                 Flat diff of everything this branch added since it forked.
--                 Three dots = merge-base, so commits that landed on the base
--                 after the fork stay out; --imply-local makes the right pane
--                 the live working-tree file, so fixes are typed in place.
--   <leader>gR  Branch review, commit-by-commit — :DiffviewFileHistory --range=
--   Base ref is resolved by utils.git-base (cached → git-flow → merge-base →
--   remote HEAD), never hardcoded; :DiffviewBase shows/sets/clears it.
-- Owned elsewhere:
--   <leader>og                   mini.diff buffer overlay vs HEAD (lua/plugins/mini.lua)
--   <leader>gl/gL                Snacks.picker.git_log repo + buffer (lua/plugins/snacks.lua)
--   <leader>gs                   Snacks.picker.git_status file list (lua/plugins/snacks.lua)
-- No autocmd-driven auto-detect or auto-prompt: conflict markers are visible via
-- mini.diff overlay + ⚠N statusline; user invokes <leader>gv when ready.
return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
	keys = {
		{
			"<leader>gd",
			function()
				if not require("utils.diffview").close_if_open() then
					vim.cmd("DiffviewOpen")
				end
			end,
			desc = "Diffview working-tree (all uncommitted)",
		},
		{
			"<leader>gv",
			function()
				-- Branch 1: toggle-close if a view is open in the current tab.
				if require("utils.diffview").close_if_open() then
					return
				end
				-- Branch 2: conflict-mode trigger. mini.git summary.in_progress
				-- canonical strings (verified): bisect, cherry-pick, merge, revert,
				-- apply (rebase-apply), rebase (rebase-merge). Multiple may be
				-- comma-joined (e.g. "merge,rebase" when a rebase hits a conflict),
				-- so substring-match each candidate rather than equality.
				-- Trigger Diffview only on operations that produce 3-way conflict
				-- markers; bisect + apply are deliberately excluded.
				local summary = vim.b.minigit_summary
				local in_progress = summary and summary.in_progress or ""
				local triggers_3way = in_progress:match("merge")
					or in_progress:match("rebase")
					or in_progress:match("cherry%-pick")
					or in_progress:match("revert")
				if triggers_3way then
					vim.cmd("DiffviewOpen")
					return
				end
				-- Branch 3: rev-range prompt. Empty input is a no-op so the
				-- prompt can't accidentally fall through to bare :DiffviewOpen
				-- (which would default to working-tree vs index).
				vim.ui.input({ prompt = "Diffview rev-range: ", default = "HEAD~1..HEAD" }, function(input)
					if input and input ~= "" then
						vim.cmd("DiffviewOpen " .. input)
					end
				end)
			end,
			desc = "Diffview (toggle / conflict / range)",
		},
		{
			"<leader>gr",
			function()
				require("utils.git-base").open()
			end,
			desc = "Diffview review vs base branch",
		},
		{
			"<leader>gR",
			function()
				require("utils.git-base").open({ history = true })
			end,
			desc = "Diffview review vs base (per commit)",
		},
	},
	opts = {
		use_icons = true,
		-- Diffview's layout names invert vim's split terms: diff2_horizontal
		-- runs `vsp` (panes side by side), diff2_vertical runs `sp` (stacked).
		-- Stacked gives each pane the full window width — better for long
		-- lines than two narrow columns. Deep-merged over the defaults, so
		-- disable_diagnostics / winbar_info stay as shipped.
		-- merge_tool is left alone on purpose: it defaults to diff3_horizontal,
		-- and three stacked panes make conflict resolution cramped.
		-- g<C-x> still cycles layouts at runtime without touching this.
		view = {
			default = { layout = "diff2_vertical" },
			file_history = { layout = "diff2_vertical" },
		},
	},
}

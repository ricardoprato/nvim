-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

-- Leader group clues for mini.clue (will be replaced by which-key in Phase 4)
_G.Config.leader_group_clues = {
  { mode = 'n', keys = '<Leader>a', desc = '+AI (Claude Code)' },
  { mode = 'x', keys = '<Leader>a', desc = '+AI (Claude Code)' },
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>d', desc = '+Debug' },
  { mode = 'n', keys = '<Leader>e', desc = '+Explore/Edit' },
  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>gc', desc = '+Conflict' },
  { mode = 'n', keys = '<Leader>gf', desc = '+Flow' },
  { mode = 'n', keys = '<Leader>l', desc = '+Language' },
  { mode = 'n', keys = '<Leader>n', desc = '+Notes (Obsidian)' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>r', desc = '+Replace' },
  { mode = 'x', keys = '<Leader>r', desc = '+Replace' },
  { mode = 'n', keys = '<Leader>s', desc = '+Session' },
  { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },
  { mode = 'x', keys = '<Leader>g', desc = '+Git' },
  { mode = 'x', keys = '<Leader>l', desc = '+Language' },
}

-- General mappings ===========================================================

-- Use this section to add custom general mappings. See `:h vim.keymap.set()`.

-- An example helper to create a Normal mode mapping
local nmap = function(lhs, rhs, desc)
	-- See `:h vim.keymap.set()`
	vim.keymap.set("n", lhs, rhs, { desc = desc })
end

-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap("[p", '<Cmd>exe "put! " . v:register<CR>', "Paste Above")
nmap("]p", '<Cmd>exe "put "  . v:register<CR>', "Paste Below")

-- Window navigation (Kitty-aware if inside Kitty, plain vim otherwise)
if vim.env.KITTY_WINDOW_ID then
	local kitty_nav = require("utils.kitty-nav")
	nmap("<C-h>", function()
		kitty_nav.navigate("h")
	end, "Move to left window")
	nmap("<C-j>", function()
		kitty_nav.navigate("j")
	end, "Move to lower window")
	nmap("<C-k>", function()
		kitty_nav.navigate("k")
	end, "Move to upper window")
	nmap("<C-l>", function()
		kitty_nav.navigate("l")
	end, "Move to right window")
else
	nmap("<C-h>", "<C-w>h", "Move to left window")
	nmap("<C-j>", "<C-w>j", "Move to lower window")
	nmap("<C-k>", "<C-w>k", "Move to upper window")
	nmap("<C-l>", "<C-w>l", "Move to right window")
end

-- Many general mappings are created by 'mini.basics'. See 'plugin/30_mini.lua'

-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- Leader mappings ============================================================

-- Neovim has the concept of a Leader key (see `:h <Leader>`). It is a configurable
-- key that is primarily used for "workflow" mappings (opposed to text editing).
-- Like "open file explorer", "create scratch buffer", "pick from buffers".
--
-- In 'plugin/10_options.lua' <Leader> is set to <Space>, i.e. press <Space>
-- whenever there is a suggestion to press <Leader>.
--
-- This config uses a "two key Leader mappings" approach: first key describes
-- semantic group, second key executes an action. Both keys are usually chosen
-- to create some kind of mnemonic.
-- Example: `<Leader>f` groups "find" type of actions; `<Leader>ff` - find files.
-- Use this section to add Leader mappings in a structural manner.
--
-- Usually if there are global and local kinds of actions, lowercase second key
-- denotes global and uppercase - local.
-- Example: `<Leader>fs` / `<Leader>fS` - find workspace/document LSP symbols.
--
-- Many of the mappings use 'mini.nvim' modules set up in 'plugin/30_mini.lua'.

-- Helpers for a more concise `<Leader>` mappings.
-- Most of the mappings use `<Cmd>...<CR>` string as a right hand side (RHS) in
-- an attempt to be more concise yet descriptive. See `:h <Cmd>`.
-- This approach also doesn't require the underlying commands/functions to exist
-- during mapping creation: a "lazy loading" approach to improve startup time.
local nmap_leader = function(suffix, rhs, desc)
	vim.keymap.set("n", "<Leader>" .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
	vim.keymap.set("x", "<Leader>" .. suffix, rhs, { desc = desc })
end

nmap("<Esc>", "<Cmd>nohlsearch<CR>", "Clear search highlight")

-- b is for 'Buffer'. Common usage:
-- - `<Leader>bs` - create scratch (temporary) buffer
-- - `<Leader>ba` - navigate to the alternative buffer
-- - `<Leader>bw` - wipeout (fully delete) current buffer
local new_scratch_buffer = function()
	vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

nmap_leader("ba", "<Cmd>b#<CR>", "Alternate")
nmap_leader("bs", new_scratch_buffer, "Scratch")
nmap_leader("bo", "<Cmd>%bd|e#<CR>", "Delete all!")

-- a is for 'AI' (Claude Code CLI). Common usage:
nmap_leader("aa", "<Cmd>ClaudeCode<CR>", "Toggle terminal")
nmap_leader("af", "<Cmd>ClaudeCodeFocus<CR>", "Focus terminal")
nmap_leader("ar", "<Cmd>ClaudeCode --resume<CR>", "Resume conversation")
nmap_leader("ac", "<Cmd>ClaudeCode --continue<CR>", "Continue conversation")
nmap_leader("am", "<Cmd>ClaudeCodeSelectModel<CR>", "Select model")
nmap_leader("ab", "<Cmd>ClaudeCodeAdd %<CR>", "Add current buffer")
nmap_leader("ad", "<Cmd>ClaudeCodeDiffAccept<CR>", "Accept diff")
nmap_leader("aD", "<Cmd>ClaudeCodeDiffDeny<CR>", "Deny diff")
xmap_leader("as", "<Cmd>ClaudeCodeSend<CR>", "Send selection to Claude")

-- Add file from explorer to Claude Code context (filetype-scoped)
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "snacks_explorer", "netrw" },
	callback = function(args)
		vim.keymap.set("n", "<Leader>as", "<Cmd>ClaudeCodeTreeAdd<CR>", {
			buffer = args.buf,
			desc = "Add file to Claude",
		})
	end,
})

-- e is for 'Explore' and 'Edit'. Common usage:
-- - `<Leader>ei` - edit 'init.lua'
-- - All mappings that use `edit_plugin_file` - edit 'plugin/' config files
-- NOTE: <Leader>ed, ef, en, eo are now in snacks.lua
local edit_plugin_file = function(filename)
	return string.format("<Cmd>edit %s/plugin/%s<CR>", vim.fn.stdpath("config"), filename)
end
local explore_quickfix = function()
	for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.fn.getwininfo(win_id)[1].quickfix == 1 then
			return vim.cmd("cclose")
		end
	end
	vim.cmd("copen")
end

nmap_leader("ei", "<Cmd>edit $MYVIMRC<CR>", "init.lua")
nmap_leader("ek", edit_plugin_file("20_keymaps.lua"), "Keymaps config")
nmap_leader("em", edit_plugin_file("30_mini.lua"), "MINI config")
nmap_leader("ep", edit_plugin_file("40_plugins.lua"), "Plugins config")
nmap_leader("eq", explore_quickfix, "Quickfix")

-- r is for 'Replace'. Common usage:
-- - `<Leader>rr` - open grug-far search/replace
-- - `<Leader>rw` - search/replace word under cursor
-- - `<Leader>rf` - search/replace scoped to current file
nmap_leader("rr", "<Cmd>GrugFar<CR>", "Search & Replace")
nmap_leader(
	"rw",
	'<Cmd>lua require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })<CR>',
	"Replace word under cursor"
)
nmap_leader(
	"rf",
	'<Cmd>lua require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })<CR>',
	"Replace in file"
)
xmap_leader("rr", ':<C-u>lua require("grug-far").with_visual_selection()<CR>', "Replace selection")

-- g is for 'Git'. Common usage:
-- - `<Leader>gs` - show information at cursor
-- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
local git_log_buf_cmd = git_log_cmd .. " --follow -- %"

nmap_leader("ga", "<Cmd>Git diff --cached<CR>", "Added diff")
nmap_leader("gA", "<Cmd>Git diff --cached -- %<CR>", "Added diff buffer")
nmap_leader("gc", "<Cmd>Git commit<CR>", "Commit")
nmap_leader("gC", "<Cmd>Git commit --amend<CR>", "Commit amend")
nmap_leader("gd", "<Cmd>Git diff<CR>", "Diff")
nmap_leader("gD", "<Cmd>Git diff -- %<CR>", "Diff buffer")
nmap_leader("gl", "<Cmd>" .. git_log_cmd .. "<CR>", "Log")
nmap_leader("gL", "<Cmd>" .. git_log_buf_cmd .. "<CR>", "Log buffer")
nmap_leader("go", "<Cmd>lua MiniDiff.toggle_overlay()<CR>", "Toggle overlay")
nmap_leader("gs", "<Cmd>lua MiniGit.show_at_cursor()<CR>", "Show at cursor")
nmap_leader("gP", "<Cmd>Git push<CR>", "Git push")
nmap_leader("gp", "<Cmd>Git pull --rebase<CR>", "Git pull")
nmap_leader("gb", "<Cmd>vertical Git blame -- %<CR>", "Git blame")
nmap_leader("gB", "<Cmd>lua Snacks.picker.git_branches()<CR>", "Git branches")
nmap_leader("gv", "<Cmd>DiffviewOpen<CR>", "Diffview open")
nmap_leader("gV", "<Cmd>DiffviewClose<CR>", "Diffview close")
nmap_leader("g-", "<Cmd>Git checkout -<CR>", "Git checkout -")

xmap_leader("gs", "<Cmd>lua MiniGit.show_at_cursor()<CR>", "Show at selection")

-- Git Flow integration
nmap_leader("gfi", '<Cmd>lua require("utils.git-flow").auto_init()<CR>', "Flow: Init")
-- gff - Feature operations
nmap_leader("gffs", "<Cmd>GitFlow feature start<CR>", "Feature: Start")
nmap_leader("gfff", "<Cmd>GitFlow feature finish<CR>", "Feature: Finish")
nmap_leader("gffp", "<Cmd>GitFlow feature publish<CR>", "Feature: Publish")
nmap_leader("gffd", "<Cmd>GitFlow feature delete<CR>", "Feature: Delete")
nmap_leader("gffl", "<Cmd>GitFlow feature list<CR>", "Feature: List")

-- gfr - Release operations
nmap_leader("gfrs", "<Cmd>GitFlow release start<CR>", "Release: Start")
nmap_leader("gfrf", "<Cmd>GitFlow release finish<CR>", "Release: Finish")
nmap_leader("gfrp", "<Cmd>GitFlow release publish<CR>", "Release: Publish")
nmap_leader("gfrd", "<Cmd>GitFlow release delete<CR>", "Release: Delete")
nmap_leader("gfrl", "<Cmd>GitFlow release list<CR>", "Release: List")

-- gfh - Hotfix operations
nmap_leader("gfhs", "<Cmd>GitFlow hotfix start<CR>", "Hotfix: Start")
nmap_leader("gfhf", "<Cmd>GitFlow hotfix finish<CR>", "Hotfix: Finish")
nmap_leader("gfhp", "<Cmd>GitFlow hotfix publish<CR>", "Hotfix: Publish")
nmap_leader("gfhd", "<Cmd>GitFlow hotfix delete<CR>", "Hotfix: Delete")
nmap_leader("gfhl", "<Cmd>GitFlow hotfix list<CR>", "Hotfix: List")

-- gfb - Bugfix operations
nmap_leader("gfbs", "<Cmd>GitFlow bugfix start<CR>", "Bugfix: Start")
nmap_leader("gfbf", "<Cmd>GitFlow bugfix finish<CR>", "Bugfix: Finish")
nmap_leader("gfbp", "<Cmd>GitFlow bugfix publish<CR>", "Bugfix: Publish")
nmap_leader("gfbd", "<Cmd>GitFlow bugfix delete<CR>", "Bugfix: Delete")
nmap_leader("gfbl", "<Cmd>GitFlow bugfix list<CR>", "Bugfix: List")

-- Git Conflict resolution
-- Navigate and resolve merge conflicts
nmap("]x", '<Cmd>lua require("utils.git-conflict").next_conflict()<CR>', "Next conflict")
nmap("[x", '<Cmd>lua require("utils.git-conflict").prev_conflict()<CR>', "Prev conflict")
nmap_leader("gco", '<Cmd>lua require("utils.git-conflict").choose_ours()<CR>', "Conflict: Ours")
nmap_leader("gct", '<Cmd>lua require("utils.git-conflict").choose_theirs()<CR>', "Conflict: Theirs")
nmap_leader("gcb", '<Cmd>lua require("utils.git-conflict").choose_both()<CR>', "Conflict: Both")
nmap_leader("gcl", '<Cmd>lua require("utils.git-conflict").list_conflicts()<CR>', "Conflict: List all")

-- l is for 'Language'. Common usage:
-- - `<Leader>ld` - show more diagnostic details in a floating window
-- - `<Leader>lr` - perform rename via LSP
-- - `<Leader>ls` - navigate to source definition of symbol under cursor
--
-- NOTE: most LSP mappings represent a more structured way of replacing built-in
-- LSP mappings (like `:h gra` and others). This is needed because `gr` is mapped
-- by an "replace" operator in 'mini.operators' (which is more commonly used).
local formatting_cmd = '<Cmd>lua require("conform").format({lsp_fallback=true})<CR>'

nmap_leader("la", "<Cmd>lua vim.lsp.buf.code_action()<CR>", "Actions")
nmap_leader("ld", "<Cmd>lua vim.diagnostic.open_float()<CR>", "Diagnostic popup")
nmap_leader("lf", formatting_cmd, "Format")
nmap_leader("li", "<Cmd>lua vim.lsp.buf.implementation()<CR>", "Implementation")
nmap_leader("lh", "<Cmd>lua vim.lsp.buf.hover()<CR>", "Hover")
nmap_leader("lr", "<Cmd>lua vim.lsp.buf.rename()<CR>", "Rename")
nmap_leader("lR", "<Cmd>lua vim.lsp.buf.references()<CR>", "References")
nmap_leader("ls", "<Cmd>lua vim.lsp.buf.definition()<CR>", "Source definition")
nmap_leader("lt", "<Cmd>lua vim.lsp.buf.type_definition()<CR>", "Type definition")

xmap_leader("lf", formatting_cmd, "Format selection")

-- Use LSP hover with K when LSP is available (instead of man pages)
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("lsp_attach_keymaps", { clear = true }),
	callback = function(args)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = args.buf, desc = "LSP Hover" })
	end,
})

-- o is for 'Other'. Common usage:
-- NOTE: <Leader>oz (zen), <Leader>od (dim) are now in snacks.lua
-- NOTE: Toggle mappings (\s, \w, \r, \d, \h) are now in snacks.lua
nmap_leader("or", "<Cmd>lua MiniMisc.resize_window()<CR>", "Resize to default width")
nmap_leader("ot", "<Cmd>lua MiniTrailspace.trim()<CR>", "Trim trailspace")

-- s is for 'Session'. Common usage:
-- - `<Leader>sn` - start new session
-- - `<Leader>sr` - read previously started session
-- - `<Leader>sd` - delete previously started session
local session_new = 'MiniSessions.write(vim.fn.input("Session name: "))'

nmap_leader("sd", '<Cmd>lua MiniSessions.select("delete")<CR>', "Delete")
nmap_leader("sn", "<Cmd>lua " .. session_new .. "<CR>", "New")
nmap_leader("sp", '<Cmd>lua require("utils.project-session").save()<CR>', "Save project session")
nmap_leader("sr", '<Cmd>lua MiniSessions.select("read")<CR>', "Read")
nmap_leader("sw", "<Cmd>lua MiniSessions.write()<CR>", "Write current")

-- t is for 'Terminal'
nmap_leader("tT", "<Cmd>horizontal term<CR>", "Terminal (horizontal)")
nmap_leader("tt", "<Cmd>vertical term<CR>", "Terminal (vertical)")

local map = vim.keymap.set
-- [[ Terminal Window Navigation ]]
-- map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
if vim.env.KITTY_WINDOW_ID then
	local kitty_nav = require("utils.kitty-nav")
	map("t", "<C-h>", function()
		vim.cmd("stopinsert")
		kitty_nav.navigate("h")
	end, { desc = "Move to left window (Terminal)" })
	map("t", "<C-j>", function()
		vim.cmd("stopinsert")
		kitty_nav.navigate("j")
	end, { desc = "Move to lower window (Terminal)" })
	map("t", "<C-k>", function()
		vim.cmd("stopinsert")
		kitty_nav.navigate("k")
	end, { desc = "Move to upper window (Terminal)" })
	map("t", "<C-l>", function()
		vim.cmd("stopinsert")
		kitty_nav.navigate("l")
	end, { desc = "Move to right window (Terminal)" })
else
	map("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Move to left window (Terminal)" })
	map("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Move to lower window (Terminal)" })
	map("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Move to upper window (Terminal)" })
	map("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Move to right window (Terminal)" })
end

-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
nmap_leader("vv", '<Cmd>lua MiniVisits.add_label("core")<CR>', 'Add "core" label')
nmap_leader("vV", '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader("vl", "<Cmd>lua MiniVisits.add_label()<CR>", "Add label")
nmap_leader("vL", "<Cmd>lua MiniVisits.remove_label()<CR>", "Remove label")

-- n is for 'Notes' (Obsidian). Common usage:
-- - `<Leader>nn` - create a new note
-- - `<Leader>nd` - open today's daily note
-- - `<Leader>ns` - search notes
nmap_leader("nn", "<Cmd>Obsidian new<CR>", "New note")
nmap_leader("no", "<Cmd>Obsidian open<CR>", "Open in app")
nmap_leader("ns", "<Cmd>Obsidian search<CR>", "Search")
nmap_leader("nd", "<Cmd>Obsidian today<CR>", "Daily note")
nmap_leader("ny", "<Cmd>Obsidian yesterday<CR>", "Yesterday")
nmap_leader("nm", "<Cmd>Obsidian tomorrow<CR>", "Tomorrow")
nmap_leader("nb", "<Cmd>Obsidian backlinks<CR>", "Backlinks")
nmap_leader("nl", "<Cmd>Obsidian links<CR>", "Links")
nmap_leader("nt", "<Cmd>Obsidian template<CR>", "Template")

-- :GitFlow command (from plugin/21_git_flow.lua)
vim.api.nvim_create_user_command('GitFlow', function(opts)
  require('utils.git-flow').command(opts)
end, {
  nargs = '*',
  complete = function(arg_lead, cmd_line, cursor_pos)
    return require('utils.git-flow').complete(arg_lead, cmd_line, cursor_pos)
  end,
  desc = 'Execute git-flow commands',
})

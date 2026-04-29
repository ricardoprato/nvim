-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

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

-- Leader mappings ============================================================

local nmap_leader = function(suffix, rhs, desc)
	vim.keymap.set("n", "<Leader>" .. suffix, rhs, { desc = desc })
end

nmap("<Esc>", "<Cmd>nohlsearch<CR>", "Clear search highlight")

-- b is for 'Buffer'
local new_scratch_buffer = function()
	vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

nmap_leader("ba", "<Cmd>b#<CR>", "Alternate")
nmap_leader("bs", new_scratch_buffer, "Scratch")

-- e is for 'Explore' and 'Edit'
-- NOTE: <Leader>ed, ef, en, eo are now in snacks.lua
local explore_quickfix = function()
	for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.fn.getwininfo(win_id)[1].quickfix == 1 then
			return vim.cmd("cclose")
		end
	end
	vim.cmd("copen")
end

nmap_leader("ei", "<Cmd>edit $MYVIMRC<CR>", "init.lua")
nmap_leader(
	"ek",
	string.format("<Cmd>edit %s/lua/config/keymaps.lua<CR>", vim.fn.stdpath("config")),
	"Keymaps config"
)
nmap_leader(
	"em",
	string.format("<Cmd>edit %s/lua/plugins/mini.lua<CR>", vim.fn.stdpath("config")),
	"MINI config"
)
nmap_leader(
	"ep",
	string.format("<Cmd>edit %s/lua/plugins/snacks.lua<CR>", vim.fn.stdpath("config")),
	"Snacks config"
)
nmap_leader("eq", explore_quickfix, "Quickfix")

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


-- t is for 'Terminal'
nmap_leader("tT", "<Cmd>horizontal term<CR>", "Terminal (horizontal)")
nmap_leader("tt", "<Cmd>vertical term<CR>", "Terminal (vertical)")

local map = vim.keymap.set
-- [[ Terminal Window Navigation ]]
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

-- :GitFlow command
vim.api.nvim_create_user_command("GitFlow", function(opts)
	require("utils.git-flow").command(opts)
end, {
	nargs = "*",
	complete = function(arg_lead, cmd_line, cursor_pos)
		return require("utils.git-flow").complete(arg_lead, cmd_line, cursor_pos)
	end,
	desc = "Execute git-flow commands",
})

-- :KeymapAudit command
--   :KeymapAudit         → readonly markdown scratch buffer with findings
--   :KeymapAudit write   → also writes to .planning/phases/01-foundation/KEYMAP-BASELINE.md
local KEYMAP_AUDIT_BASELINE = vim.fn.stdpath("config") .. "/.planning/phases/01-foundation/KEYMAP-BASELINE.md"
vim.api.nvim_create_user_command("KeymapAudit", function(opts)
	local arg = vim.trim(opts.args or "")
	if arg == "" then
		require("utils.keymap-audit").run(nil)
	elseif arg == "write" then
		require("utils.keymap-audit").run(KEYMAP_AUDIT_BASELINE)
	else
		vim.notify("Usage: :KeymapAudit | :KeymapAudit write", vim.log.levels.WARN)
	end
end, {
	nargs = "?",
	complete = function(arg_lead)
		return vim.tbl_filter(function(s)
			return vim.startswith(s, arg_lead)
		end, { "write" })
	end,
	desc = "Audit keymaps for collisions, undeclared groups, and dead targets",
})

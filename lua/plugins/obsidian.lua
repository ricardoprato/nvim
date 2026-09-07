-- Obsidian: the ~/obsidian vault — dailies, weeklies, captures and search,
-- all under the <leader>n prefix. Split out of lua/plugins/editor.lua: the
-- capture helpers below only serve this plugin.

-- Vault root, single source of truth: the lazy event patterns, the workspace
-- definition and the weekly-note path all derive from it, so moving the vault is
-- a one-line change instead of four.
local VAULT = vim.fn.expand("~/obsidian")

-- obsidian.actions.new_from_template writes the note to disk and stops there —
-- "The caller decides whether to open the note; this function never opens it."
-- Every note-creating keymap below goes through these helpers so the open
-- callback lives in exactly one place.

---@param id string        vault-relative note id, "<folder>/<title>"
---@param template string? nil creates a templateless note (frontmatter only)
---@param on_open fun(note: obsidian.Note)? runs with the new note's buffer current
local function new_note(id, template, on_open)
	local actions = require("obsidian.actions")
	local open = function(note)
		note:open({ sync = true })
		if on_open then
			on_open(note)
		end
	end
	-- new_from_template with a nil template creates nothing: it opens the template
	-- picker. A templateless capture goes through actions.new, which applies
	-- opts.note.template (the plugin's frontmatter-only default).
	if template then
		actions.new_from_template(id, template, open)
	else
		actions.new(id, open)
	end
end

---Prompt for a title and create the note under a fixed folder + template.
---@param prompt string    input prompt, ": " is appended
---@param folder string    vault-relative folder the note lands in
---@param template string?
---@param on_open fun(note: obsidian.Note)?
local function capture(prompt, folder, template, on_open)
	local title = vim.fn.input(prompt .. ": ")
	if title == "" then
		return
	end
	new_note(folder .. "/" .. title, template, on_open)
end

---Fill `language:` in the frontmatter and the opening code fence of a snippet note.
---@param lang string
local function set_snippet_language(lang)
	vim.schedule(function()
		local buf = vim.api.nvim_get_current_buf()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		for i, line in ipairs(lines) do
			if line:match("^language:") then
				lines[i] = "language: " .. lang
			-- A bare fence whose predecessor isn't a fence is the opening one.
			elseif line == "```" and not (i > 1 and lines[i - 1]:match("^```")) then
				lines[i] = "```" .. lang
				break
			end
		end
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	end)
end

return {
	"obsidian-nvim/obsidian.nvim",
	event = {
		"BufReadPre " .. VAULT .. "/**.md",
		"BufNewFile " .. VAULT .. "/**.md",
	},
	cmd = "Obsidian",
	keys = {
		-- Daily & weekly
		{ "<leader>nd", "<Cmd>Obsidian today<CR>", desc = "Work daily (today)" },
		-- workdays_only is on (see opts), so these two skip the weekend.
		{ "<leader>ny", "<Cmd>Obsidian yesterday<CR>", desc = "Yesterday (workday)" },
		{ "<leader>nm", "<Cmd>Obsidian tomorrow<CR>", desc = "Tomorrow (workday)" },
		{
			"<leader>nw",
			function()
				-- ISO week (%G-W%V, not %Y-W%W): personal-weekly.md stamps
				-- `week: {{date:WW}}` in its frontmatter, and moment's WW is
				-- the ISO week — %W would disagree with it by one most years.
				local rel = "personal/" .. os.date("%G-W%V")
				local path = VAULT .. "/" .. rel .. ".md"
				if vim.fn.filereadable(path) == 1 then
					vim.cmd("edit " .. vim.fn.fnameescape(path))
				else
					new_note(rel, "personal-weekly")
				end
			end,
			desc = "Personal weekly",
		},

		-- Quick capture to specific folders
		{
			"<leader>nz",
			function()
				capture("Zettel", "zettelkasten", "zettel")
			end,
			desc = "New zettel",
		},
		-- Templateless on purpose: an inbox capture is a title and a body.
		{
			"<leader>nc",
			function()
				capture("Capture", "inbox", nil)
			end,
			desc = "Quick capture (inbox)",
		},
		{
			"<leader>ni",
			function()
				capture("Idea", "personal", "idea")
			end,
			desc = "New idea",
		},
		{
			"<leader>nk",
			function()
				capture("Snippet", "snippets", "snippet", function()
					local lang = vim.fn.input("Language: ")
					if lang ~= "" then
						set_snippet_language(lang)
					end
				end)
			end,
			desc = "New snippet",
		},
		{
			"<leader>np",
			function()
				capture("Project", "work/projects", "project")
			end,
			desc = "New project note",
		},

		-- Snippet search
		{
			"<leader>nf",
			function()
				require("utils.obsidian-snippets").find_and_yank()
			end,
			desc = "Find snippet (yank code)",
		},
		{
			"<leader>nF",
			function()
				require("utils.obsidian-snippets").search()
			end,
			desc = "Search snippets (grep)",
		},

		-- Search & navigation
		{ "<leader>ns", "<Cmd>Obsidian search<CR>", desc = "Search" },
		{ "<leader>nb", "<Cmd>Obsidian backlinks<CR>", desc = "Backlinks" },
		{ "<leader>nl", "<Cmd>Obsidian links<CR>", desc = "Links" },
		{ "<leader>nt", "<Cmd>Obsidian template<CR>", desc = "Insert template" },
		{ "<leader>nn", "<Cmd>Obsidian new<CR>", desc = "New note" },
		{ "<leader>no", "<Cmd>Obsidian open<CR>", desc = "Open in app" },
		{ "<leader>nT", "<Cmd>Obsidian tags<CR>", desc = "Search by tag" },
	},
	opts = {
		workspaces = { { name = "personal", path = VAULT } },
		legacy_commands = false,

		daily_notes = {
			folder = "work/daily",
			date_format = "%Y-%m-%d",
			template = "work-daily",
			default_tags = { "daily", "work" },
			-- Upstream's default, pinned here because it drives <leader>ny/nm:
			-- these are work dailies, so Monday's "yesterday" is Friday.
			workdays_only = true,
		},

		templates = {
			folder = "templates",
			date_format = "%Y-%m-%d",
			time_format = "%H:%M",
		},

		-- Transliterate before filtering to ASCII. Stripping straight away
		-- deleted accented characters instead of folding them, which mangles
		-- Spanish titles: "Presupuesto Ñandú" became "presupuesto-and", and a
		-- title of only accented letters became an empty id. //TRANSLIT folds
		-- them ("Ñandú" → "Nandu"); the timestamp stays as the last resort.
		note_id_func = function(title)
			if not title then
				return tostring(os.time())
			end
			local ascii = vim.iconv(title, "utf-8", "ascii//TRANSLIT") or title
			local id = ascii:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
			return id ~= "" and id or tostring(os.time())
		end,

		attachments = { folder = "assets" },

		-- Notes created without an explicit folder (<leader>nn, following a
		-- link to a missing note) land in inbox/ rather than loose in the vault
		-- root, which is where they went while notes_subdir was unset.
		-- The <leader>n captures pass "<folder>/<title>" and bypass this.
		new_notes_location = "notes_subdir",
		notes_subdir = "inbox",
	},
}

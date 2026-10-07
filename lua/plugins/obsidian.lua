-- Obsidian: the ~/obsidian vault, used journal-first — the daily note is the
-- single entry point and topics are linked inline, so a topic note's backlinks
-- list every daily that mentions it. All keymaps live under <leader>n.

-- Vault root, single source of truth: the lazy event patterns, the workspace
-- definition and the weekly-note path all derive from it, so moving the vault is
-- a one-line change instead of four.
local VAULT = vim.fn.expand("~/obsidian")

-- new_from_template writes the note and stops there: "The caller decides
-- whether to open the note; this function never opens it." Creating the note
-- from the template (instead of :Obsidian template into an existing note) also
-- avoids a second frontmatter block, which the insert path leaves behind.
---@param id string        vault-relative note id, "<folder>/<title>"
---@param template string
local function new_note(id, template)
	require("obsidian.actions").new_from_template(id, template, function(note)
		note:open({ sync = true })
	end)
end

---Prompt for a title and create the note under a fixed folder + template.
---@param prompt string
---@param folder string vault-relative folder the note lands in
---@param template string
local function capture(prompt, folder, template)
	local title = vim.fn.input(prompt .. ": ")
	if title ~= "" then
		new_note(folder .. "/" .. title, template)
	end
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
		{ "<leader>nd", "<Cmd>Obsidian today<CR>", desc = "Daily (today)" },
		{ "<leader>ny", "<Cmd>Obsidian yesterday<CR>", desc = "Daily (yesterday)" },
		{ "<leader>nm", "<Cmd>Obsidian tomorrow<CR>", desc = "Daily (tomorrow)" },
		-- Journal-first review: the dailies are the only entry point, so the
		-- weekly pass over them is what promotes recurring themes to topic notes.
		{ "<leader>nr", "<Cmd>Obsidian dailies -7 0<CR>", desc = "Review last week's dailies" },

		-- Journal-first linking: a line in the daily becomes findable by linking
		-- a topic; the topic note's backlinks then list every daily that mentions it.
		{ "<leader>nL", ":Obsidian link_new<CR>", mode = "x", desc = "Link selection to new topic" },
		{ "<leader>nl", ":Obsidian link<CR>", mode = "x", desc = "Link selection to existing note" },
		{ "<leader>nq", "<Cmd>Obsidian quick_switch<CR>", desc = "Quick switch note" },
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

		-- Tracked collections: one note per item, listed by the Bases in
		-- media.md and ideas.md at the vault root, not by browsing the folders.
		{
			"<leader>nv",
			function()
				capture("Serie/película", "media", "media")
			end,
			desc = "New series/movie",
		},
		{
			"<leader>ni",
			function()
				capture("Idea", "ideas", "idea")
			end,
			desc = "New idea (game/content)",
		},
		{
			"<leader>nh",
			function()
				vim.cmd.edit(VAULT .. "/home.md")
			end,
			desc = "Vault home",
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
			-- One daily for everything, work or not: it is the journal-first entry
			-- point, so it lives at the vault root rather than under work/.
			folder = "daily",
			template = "daily",
			default_tags = { "daily" },
			-- Upstream defaults to true, which made Monday's "yesterday" Friday.
			-- Weekend dailies exist now, so <leader>ny/nm must not skip them.
			workdays_only = false,
		},

		templates = { folder = "templates" },

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

		-- render-markdown.nvim owns rendering. obsidian.nvim only skips its own
		-- UI when a renderer is already loaded at workspace setup, but it loads
		-- on BufReadPre, before render-markdown's ft=markdown trigger, so both
		-- drew checkboxes: the stacked conceals ate the first letters of a task.
		ui = { enable = false },

		-- Unset, obsidian.nvim auto-detects in the order telescope, fzf-lua,
		-- mini.pick, snacks — and mini.nvim is installed for its other modules,
		-- so search and backlinks opened in mini.pick instead of snacks.
		picker = { name = "snacks.picker" },

		-- Notes created without an explicit folder (<leader>nn, <CR> on a link to
		-- a missing note, <leader>nL) are journal-first topic notes: permanent
		-- hubs whose value is their backlinks. There is no inbox: unsorted
		-- captures go in the daily, so topics/ only ever holds topics.
		new_notes_location = "notes_subdir",
		notes_subdir = "topics",
	},
}

# Lazy + Snacks Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Neovim config from mini.deps to lazy.nvim, replace 12 mini.nvim UI modules with snacks.nvim + lualine + bufferline + noice + which-key, and add 10 new features.

**Architecture:** Modular `lua/plugins/` directory with one lazy spec per plugin/group. Config (options, keymaps, autocmds) in `lua/config/`. Retained mini.nvim modules in a single `lua/plugins/mini.lua`. All lazy-loading managed by lazy.nvim's `event`/`cmd`/`ft`/`keys` system.

**Tech Stack:** lazy.nvim, snacks.nvim, lualine.nvim, bufferline.nvim, noice.nvim, which-key.nvim, catppuccin, mini.nvim (22 retained modules)

**Spec:** `docs/superpowers/specs/2026-03-13-lazy-snacks-migration-design.md`

---

## Chunk 1: Phase 0 — Preparation

### Task 1: Commit current changes and create migration branch

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Commit current uncommitted work**

```bash
git add lua/utils/root.lua lua/utils/git.lua plugin/40_plugins.lua
git commit -m "fix: use io.popen in root.lua/git.lua, switch conform to format_after_save

Prevents LSP RPC re-entrance crash ('response id must be a number') by avoiding
vim.fn.system() and vim.system():wait() which pump the Neovim event loop."
```

- [ ] **Step 2: Create migration branch**

```bash
git checkout -b feat/lazy-migration
```

- [ ] **Step 3: Add .superpowers/ and docs/ to .gitignore**

Append to `.gitignore`:
```
.superpowers/
docs/
```

- [ ] **Step 4: Commit .gitignore**

```bash
git add .gitignore
git commit -m "chore: add .superpowers/ and docs/ to gitignore"
```

### Task 2: Extract options to lua/config/options.lua

**Files:**
- Create: `lua/config/options.lua`
- Reference: `plugin/10_options.lua`

- [ ] **Step 1: Create lua/config/ directory**

```bash
mkdir -p lua/config
```

- [ ] **Step 2: Create lua/config/options.lua**

Copy the entire content of `plugin/10_options.lua` into `lua/config/options.lua` with these changes:
- Remove the `MiniDeps.later()` call around `vim.diagnostic.config()` (line 220) — replace with just `vim.diagnostic.config(diagnostic_opts)`. Lazy.nvim will handle load order.
- Remove the three general autocommands that will move to `autocmds.lua` in Task 4: the `formatoptions` FileType autocmd, the `FocusGained`/`BufEnter` checktime autocmd, and the `BufWinEnter` q-close autocmd. These use `_G.Config.new_autocmd` — remove them entirely (they'll be recreated in `autocmds.lua`).
- Any remaining `_G.Config.new_autocmd` calls (bigfile-related) — replace with `vim.api.nvim_create_autocmd` using a local `bigfile` augroup.
- Keep everything else as-is (options, bigfile detection, diagnostic config).

Verification: File should be ~210 lines. All `vim.o.*` settings, bigfile detection, and diagnostics present. No general autocommands (those are in `autocmds.lua`).

- [ ] **Step 3: Commit**

```bash
git add lua/config/options.lua
git commit -m "refactor: extract options to lua/config/options.lua"
```

### Task 3: Extract keymaps to lua/config/keymaps.lua

**Files:**
- Create: `lua/config/keymaps.lua`
- Reference: `plugin/20_keymaps.lua`, `plugin/21_git_flow.lua`

- [ ] **Step 1: Create lua/config/keymaps.lua**

Copy content of `plugin/20_keymaps.lua` into `lua/config/keymaps.lua` with these changes:
- Remove `_G.Config.leader_group_clues` table (lines 73-100) — this is mini.clue-specific, will be replaced by which-key groups in Phase 4.
- Remove the `MiniExtra.pickers`-dependent keymaps in the visits section: the `make_pick_core` function (line 412-413) and the `vc`/`vC` keymaps (lines 414-421) that use `MiniExtra.pickers.visit_paths`. Keep the `vv`/`vV`/`vl`/`vL` keymaps (lines 422-425) — they only call `MiniVisits.add_label()`/`remove_label()` which work fine since `MiniVisits` creates a global table. The removed `vc`/`vC` pickers will move to `lua/plugins/mini.lua`.
- Keep all other keymaps as-is. Keymaps that reference `MiniXxx` will work because mini modules create global tables.
- Append `:GitFlow` command from `plugin/21_git_flow.lua` at the end.

At the end of the file, add:
```lua
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
```

- [ ] **Step 2: Commit**

```bash
git add lua/config/keymaps.lua
git commit -m "refactor: extract keymaps to lua/config/keymaps.lua"
```

### Task 4: Create lua/config/autocmds.lua

**Files:**
- Create: `lua/config/autocmds.lua`

- [ ] **Step 1: Create lua/config/autocmds.lua**

This file holds autocommands that were scattered across the old config and don't belong to any specific plugin. Extract from `plugin/10_options.lua`:
- The `formatoptions` FileType autocmd
- The `FocusGained`/`BufEnter` checktime autocmd
- The `BufWinEnter` q-close autocmd
- The `ColorScheme` tailwind cache reset autocmd (from `plugin/30_mini.lua` line 625-627)

```lua
-- Autocommands extracted from plugin/10_options.lua and plugin/30_mini.lua
local augroup = vim.api.nvim_create_augroup('custom-config', { clear = true })

-- Don't auto-wrap comments and don't insert comment leader after hitting 'o'
vim.api.nvim_create_autocmd('FileType', {
  group = augroup,
  callback = function()
    vim.cmd('setlocal formatoptions-=c formatoptions-=o')
  end,
  desc = "Proper 'formatoptions'",
})

-- Reload buffers when Neovim regains focus or when switching buffers
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
  group = augroup,
  callback = function()
    if vim.o.buftype ~= '' then return end
    vim.cmd('checktime')
  end,
  desc = 'Check for external file changes',
})

-- Make q close help, man, quickfix, dap floats
vim.api.nvim_create_autocmd('BufWinEnter', {
  group = augroup,
  callback = function(args)
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = args.buf })
    if vim.tbl_contains({ 'help', 'nofile', 'quickfix' }, buftype) and vim.fn.maparg('q', 'n') == '' then
      vim.keymap.set('n', 'q', '<cmd>close<cr>', {
        desc = 'Close window',
        buffer = args.buf,
        silent = true,
        nowait = true,
      })
    end
  end,
  desc = 'Make q close help, man, quickfix, dap floats',
})

-- Reset Tailwind highlight cache on colorscheme change
vim.api.nvim_create_autocmd('ColorScheme', {
  group = augroup,
  pattern = '*',
  callback = function()
    require('utils.tailwind-colors').reset_cache()
  end,
  desc = 'Reset Tailwind highlight cache on colorscheme change',
})
```

- [ ] **Step 2: Commit**

```bash
git add lua/config/autocmds.lua
git commit -m "refactor: extract autocmds to lua/config/autocmds.lua"
```

### Task 5: Create empty lua/plugins/ and verify structure

**Files:**
- Create: `lua/plugins/` (directory)

- [ ] **Step 1: Create directory**

```bash
mkdir -p lua/plugins
```

- [ ] **Step 2: Verify directory structure**

```bash
ls -la lua/config/ lua/plugins/
```

Expected: `options.lua`, `keymaps.lua`, `autocmds.lua` in config/. Empty plugins/.

- [ ] **Step 3: Commit Phase 0**

```bash
git add lua/config/ lua/plugins/
git commit -m "refactor: Phase 0 complete — config structure prepared for lazy.nvim migration"
```

---

## Chunk 2: Phase 1 — Package Manager (mini.deps → lazy.nvim)

### Task 6: Rewrite init.lua with lazy.nvim bootstrap

**Files:**
- Modify: `init.lua`

- [ ] **Step 1: Rewrite init.lua**

Replace entire content of `init.lua` with:

```lua
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Global config table (used by utils and autocmds)
_G.Config = {}
_G.Config.initial_cwd = vim.fn.getcwd()

local augroup = vim.api.nvim_create_augroup('custom-config', {})
_G.Config.new_autocmd = function(event, pattern, callback, desc)
  vim.api.nvim_create_autocmd(event, {
    group = augroup, pattern = pattern, callback = callback, desc = desc,
  })
end

-- Load config files
require('config.options')
require('config.keymaps')
require('config.autocmds')

-- Setup lazy.nvim
require('lazy').setup({
  spec = { import = 'plugins' },
  install = { colorscheme = { 'catppuccin-mocha' } },
  checker = { enabled = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip', 'netrwPlugin', 'tarPlugin', 'tohtml', 'zipPlugin',
      },
    },
  },
})
```

- [ ] **Step 2: Commit**

```bash
git add init.lua
git commit -m "refactor: rewrite init.lua with lazy.nvim bootstrap"
```

### Task 7: Create lua/plugins/catppuccin.lua

**Files:**
- Create: `lua/plugins/catppuccin.lua`
- Reference: `plugin/40_plugins.lua` lines 257-283

- [ ] **Step 1: Create the file**

```lua
return {
  'catppuccin/nvim',
  name = 'catppuccin',
  lazy = false,
  priority = 1000,
  config = function()
    require('catppuccin').setup({
      flavour = 'auto',
      background = { light = 'latte', dark = 'mocha' },
      dim_inactive = {
        enabled = true,
        shade = 'dark',
        percentage = 0.15,
      },
      default_integrations = true,
      integrations = {
        mason = true,
        mini = { enabled = true, indentscope_color = 'mocha' },
        dap = true,
        -- New integrations (added progressively in later phases)
        -- noice = true,
        -- which_key = true,
        -- snacks = true,
      },
    })
    -- Note: changed from 'catppuccin-nvim' (repo-name artifact in mini.deps) to
    -- 'catppuccin-mocha' (correct Catppuccin flavour name, forces mocha in dark mode)
    vim.cmd.colorscheme('catppuccin-mocha')
  end,
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/catppuccin.lua
git commit -m "feat: add catppuccin lazy spec"
```

### Task 8: Create lua/plugins/mini.lua (all 34 modules initially)

**Files:**
- Create: `lua/plugins/mini.lua`
- Reference: `plugin/30_mini.lua` (entire file)

This is the largest task. It migrates ALL current mini modules into a single lazy spec. Modules that will be replaced later (Phase 2-4) are included now so the editor works after Phase 1.

- [ ] **Step 1: Create lua/plugins/mini.lua**

```lua
return {
  'echasnovski/mini.nvim',
  lazy = false,
  priority = 900,
  config = function()
    -- Step 1: modules needed for first draw ================================

    require('mini.basics').setup({
      options = { basic = false },
      mappings = { windows = false, move_with_alt = true },
    })

    -- Icons + nvim-web-devicons mock
    local ext3_blocklist = { scm = true, txt = true, yml = true }
    local ext4_blocklist = { json = true, yaml = true }
    require('mini.icons').setup({
      use_file_extension = function(ext, _)
        return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
      end,
    })
    vim.schedule(function()
      MiniIcons.mock_nvim_web_devicons()
      MiniIcons.tweak_lsp_kind()
    end)

    require('mini.misc').setup()
    MiniMisc.setup_auto_root()
    MiniMisc.setup_restore_cursor()
    MiniMisc.setup_termbg_sync()

    -- Notifications (will be replaced by snacks.notifier in Phase 3a)
    require('mini.notify').setup({
      content = {
        sort = function(notif_arr)
          notif_arr = vim.tbl_filter(function(notif)
            return not notif.msg:find(': %(%d+%%%%)%s*$')
          end, notif_arr)
          table.sort(notif_arr, function(a, b) return a.ts_update < b.ts_update end)
          return notif_arr
        end,
      },
    })

    require('mini.sessions').setup({
      directory = vim.fn.stdpath('data') .. '/sessions',
      autowrite = true,
      hooks = {
        pre = {
          write = function()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              local bt = vim.bo[buf].buftype
              if bt == 'terminal' or bt == 'nofile' then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
              end
            end
          end,
        },
      },
    })

    vim.api.nvim_create_autocmd('VimLeavePre', {
      callback = function()
        if vim.v.this_session ~= '' then
          pcall(MiniSessions.write)
        end
      end,
    })

    -- Starter (will be replaced by snacks.dashboard in Phase 3a)
    require('mini.starter').setup()

    -- Statusline (will be replaced by lualine in Phase 2)
    require('mini.statusline').setup({
      content = {
        active = function()
          local MiniStatusline = require('mini.statusline')
          local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
          local git = MiniStatusline.section_git({ trunc_width = 40 })
          local diff = MiniStatusline.section_diff({ trunc_width = 75 })
          local diagnostics = MiniStatusline.section_diagnostics({ trunc_width = 75 })
          local lsp = MiniStatusline.section_lsp({ trunc_width = 75 })
          local filename = MiniStatusline.section_filename({ trunc_width = 140 })
          local fileinfo = MiniStatusline.section_fileinfo({ trunc_width = 120 })
          local location = MiniStatusline.section_location({ trunc_width = 75 })
          local search = MiniStatusline.section_searchcount({ trunc_width = 75 })
          return MiniStatusline.combine_groups({
            { hl = mode_hl, strings = { mode } },
            { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diagnostics, lsp } },
            '%<',
            { hl = 'MiniStatuslineFilename', strings = { filename } },
            '%=',
            { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
            { hl = mode_hl, strings = { search, location } },
          })
        end,
      },
    })

    -- Tabline (will be replaced by bufferline in Phase 2)
    require('mini.tabline').setup()

    -- Step 2: deferred modules =============================================

    vim.schedule(function()
      require('mini.extra').setup()

      local ai = require('mini.ai')
      ai.setup({
        custom_textobjects = {
          B = MiniExtra.gen_ai_spec.buffer(),
          F = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
        },
        search_method = 'cover',
      })

      require('mini.align').setup()
      require('mini.bracketed').setup()
      require('mini.bufremove').setup()

      -- Clue (will be replaced by which-key in Phase 4)
      local miniclue = require('mini.clue')
      -- stylua: ignore
      miniclue.setup({
        clues = {
          Config.leader_group_clues or {},
          miniclue.gen_clues.builtin_completion(),
          miniclue.gen_clues.g(),
          miniclue.gen_clues.marks(),
          miniclue.gen_clues.registers(),
          miniclue.gen_clues.windows({ submode_resize = true }),
          miniclue.gen_clues.z(),
        },
        triggers = {
          { mode = 'n', keys = '<Leader>' },
          { mode = 'x', keys = '<Leader>' },
          { mode = 'n', keys = '\\' },
          { mode = 'n', keys = '[' },
          { mode = 'n', keys = ']' },
          { mode = 'x', keys = '[' },
          { mode = 'x', keys = ']' },
          { mode = 'i', keys = '<C-x>' },
          { mode = 'n', keys = 'g' },
          { mode = 'x', keys = 'g' },
          { mode = 'n', keys = "'" },
          { mode = 'n', keys = '`' },
          { mode = 'x', keys = "'" },
          { mode = 'x', keys = '`' },
          { mode = 'n', keys = '"' },
          { mode = 'x', keys = '"' },
          { mode = 'i', keys = '<C-r>' },
          { mode = 'c', keys = '<C-r>' },
          { mode = 'n', keys = '<C-w>' },
          { mode = 'n', keys = 'z' },
          { mode = 'x', keys = 'z' },
        },
      })

      require('mini.comment').setup()
      require('mini.cursorword').setup()
      require('mini.diff').setup()

      -- Files (will be replaced by snacks.explorer in Phase 3a)
      require('mini.files').setup({ windows = { preview = true } })
      local add_marks = function()
        MiniFiles.set_bookmark('c', vim.fn.stdpath('config'), { desc = 'Config' })
        MiniFiles.set_bookmark('p', vim.fn.stdpath('data') .. '/lazy', { desc = 'Plugins' }) -- Changed from /site/pack/deps/opt to /lazy for lazy.nvim
        MiniFiles.set_bookmark('w', vim.fn.getcwd(), { desc = 'Working directory' })
      end
      _G.Config.new_autocmd('User', 'MiniFilesExplorerOpen', add_marks, 'Add bookmarks')

      _G.Config.new_autocmd('User', 'MiniFilesBufferCreate', function(args)
        local buf_id = args.data.buf_id
        vim.keymap.set('n', '<C-g>', function()
          local entry = MiniFiles.get_fs_entry()
          if not entry then return end
          local dir = entry.fs_type == 'directory' and entry.path or vim.fs.dirname(entry.path)
          MiniFiles.close()
          vim.schedule(function()
            require('utils.float-term').lazygit(dir)
          end)
        end, { buffer = buf_id, desc = 'Open Lazygit' })
      end, 'Add git keymaps to mini.files')

      -- Git
      require('mini.git').setup()

      local format_summary = function(data)
        local summary = vim.b[data.buf].minigit_summary
        if not summary then return end
        local parts = {}
        if summary.head_name then table.insert(parts, summary.head_name) end
        local git_utils = require('utils.git')
        local status = git_utils.get_ahead_behind()
        if status.ahead > 0 then table.insert(parts, '↑' .. status.ahead) end
        if status.behind > 0 then table.insert(parts, '↓' .. status.behind) end
        if summary.in_progress and summary.in_progress ~= '' then
          table.insert(parts, '[' .. summary.in_progress .. ']')
        end
        local conflicts = git_utils.count_conflicts(data.buf)
        if conflicts > 0 then table.insert(parts, '⚠' .. conflicts) end
        if summary.status then table.insert(parts, summary.status) end
        vim.b[data.buf].minigit_summary_string = table.concat(parts, ' ')
      end

      _G.Config.new_autocmd('User', 'MiniGitUpdated', format_summary, 'Format git summary')
      _G.Config.new_autocmd('User', 'MiniGitUpdated', function()
        require('utils.git').invalidate_cache()
      end, 'Invalidate git status cache')
      _G.Config.new_autocmd('User', 'MiniGitUpdated', function()
        local git = require('utils.git')
        if not git._fetch_timer then git.start_auto_fetch(1) end
      end, 'Start background git fetch')

      local align_blame = function(au_data)
        if not au_data.data or au_data.data.git_subcommand ~= 'blame' then return end
        local win_src = au_data.data.win_source
        if not win_src or not vim.api.nvim_win_is_valid(win_src) then return end
        local win_git = vim.api.nvim_get_current_win()
        vim.wo[win_git].wrap = false
        vim.fn.winrestview({ topline = vim.fn.line('w0', win_src) })
        vim.api.nvim_win_set_cursor(win_git, { vim.fn.line('.', win_src), 0 })
        vim.wo[win_src].scrollbind = true
        vim.wo[win_git].scrollbind = true
      end
      _G.Config.new_autocmd('User', 'MiniGitCommandSplit', align_blame, 'Align blame output')

      -- Hipatterns
      local hipatterns = require('mini.hipatterns')
      local hi_words = MiniExtra.gen_highlighter.words
      hipatterns.setup({
        highlighters = {
          fixme = hi_words({ 'FIXME', 'Fixme', 'fixme' }, 'MiniHipatternsFixme'),
          hack = hi_words({ 'HACK', 'Hack', 'hack' }, 'MiniHipatternsHack'),
          todo = hi_words({ 'TODO', 'Todo', 'todo' }, 'MiniHipatternsTodo'),
          note = hi_words({ 'NOTE', 'Note', 'note' }, 'MiniHipatternsNote'),
          hex_color = hipatterns.gen_highlighter.hex_color(),
          tailwind = {
            pattern = function()
              local ft = vim.bo.filetype
              local allowed = {
                'html','css','scss','less','javascript','javascriptreact',
                'typescript','typescriptreact','vue','svelte','astro',
              }
              if not vim.tbl_contains(allowed, ft) then return nil end
              return '%f[%w:-]()[%w:-]+%-[a-z%-]+%-%d+/?%d*()%f[^%w:-]'
            end,
            group = function(_, _, match_data)
              local match = match_data.full_match
              local color, shade = match:match('[%w-]+%-([a-z%-]+)%-(%d+)')
              shade = tonumber(shade)
              local tw = require('utils.tailwind-colors')
              local bg_hex = vim.tbl_get(tw.colors, color, shade)
              if bg_hex then
                local hl_group = 'MiniHipatternsTailwind' .. color .. shade
                if not tw.hl_cache[hl_group] then
                  tw.hl_cache[hl_group] = true
                  local fg_shade = shade == 500 and 950 or shade < 500 and 900 or 100
                  local fg_hex = vim.tbl_get(tw.colors, color, fg_shade)
                  vim.api.nvim_set_hl(0, hl_group, { bg = '#' .. bg_hex, fg = '#' .. fg_hex })
                end
                return hl_group
              end
            end,
            extmark_opts = { priority = 2000 },
          },
          git_conflict_start = { pattern = '^<<<<<<< .*', group = 'DiffDelete' },
          git_conflict_sep = { pattern = '^=======', group = 'DiffChange' },
          git_conflict_end = { pattern = '^>>>>>>> .*', group = 'DiffAdd' },
        },
      })

      -- Indentscope (will be replaced by snacks.indent in Phase 3a)
      require('mini.indentscope').setup()

      require('mini.jump').setup()
      require('mini.jump2d').setup()

      require('mini.keymap').setup()
      MiniKeymap.map_multistep('i', '<CR>', { 'minipairs_cr' })
      MiniKeymap.map_multistep('i', '<BS>', { 'minipairs_bs' })

      -- Map (will be replaced by snacks.scroll in Phase 3a)
      local minimap = require('mini.map')
      minimap.setup({
        symbols = { encode = minimap.gen_encode_symbols.dot('4x2') },
        integrations = {
          minimap.gen_integration.builtin_search(),
          minimap.gen_integration.diff(),
          minimap.gen_integration.diagnostic(),
        },
      })
      for _, key in ipairs({ 'n', 'N', '*', '#' }) do
        vim.keymap.set('n', key, key .. 'zv<Cmd>lua MiniMap.refresh({}, { lines = false, scrollbar = false })<CR>')
      end

      require('mini.move').setup()

      require('mini.operators').setup()
      vim.keymap.set('n', '(', 'gxiagxila', { remap = true, desc = 'Swap arg left' })
      vim.keymap.set('n', ')', 'gxiagxina', { remap = true, desc = 'Swap arg right' })

      require('mini.pairs').setup({ modes = { command = true } })

      -- Pick (will be replaced by snacks.picker in Phase 3a)
      require('mini.pick').setup()
      local pick_utils = require('utils.pick-utils')
      MiniPick.registry.repos = pick_utils.project_picker

      -- Snippets
      local latex_patterns = { 'latex/**/*.json', '**/latex.json' }
      local lang_patterns = {
        tex = latex_patterns,
        plaintex = latex_patterns,
        markdown_inline = { 'markdown.json' },
      }
      local snippets = require('mini.snippets')
      local config_path = vim.fn.stdpath('config')
      snippets.setup({
        snippets = {
          snippets.gen_loader.from_file(config_path .. '/snippets/global.json'),
          snippets.gen_loader.from_lang({ lang_patterns = lang_patterns }),
        },
      })
      MiniSnippets.start_lsp_server()

      require('mini.splitjoin').setup()
      require('mini.surround').setup()
      require('mini.trailspace').setup()
      require('mini.visits').setup()
    end) -- end vim.schedule
  end,
}
```

- [ ] **Step 1b: Re-add leader_group_clues to keymaps.lua**

The `Config.leader_group_clues` reference in mini.clue setup needs the table to exist. Since we removed it from keymaps.lua in Task 3, temporarily add it back until Phase 4 removes mini.clue. Add to `lua/config/keymaps.lua` before the helper functions:

```lua
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
  { mode = 'n', keys = '<Leader>m', desc = '+Map' },
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
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/mini.lua lua/config/keymaps.lua
git commit -m "feat: create mini.lua lazy spec with all 34 modules"
```

### Task 9: Create lua/plugins/treesitter.lua

**Files:**
- Create: `lua/plugins/treesitter.lua`
- Reference: `plugin/40_plugins.lua` lines 33-99

- [ ] **Step 1: Create the file**

```lua
return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    event = { 'BufReadPost', 'BufNewFile' },
    build = ':TSUpdate',
    config = function()
      local languages = {
        'lua', 'vimdoc', 'markdown', 'markdown_inline',
        'python', 'xml', 'html', 'css',
        'javascript', 'typescript', 'tsx', 'jsx', 'astro',
        'bash', 'json', 'yaml', 'toml',
        'dockerfile', 'gitcommit', 'diff', 'query', 'http',
      }
      local isnt_installed = function(lang)
        return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0
      end
      local to_install = vim.tbl_filter(isnt_installed, languages)
      if #to_install > 0 then
        require('nvim-treesitter').install(to_install)
      end

      local filetypes = {}
      for _, lang in ipairs(languages) do
        for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
          table.insert(filetypes, ft)
        end
      end
      _G.Config.new_autocmd('FileType', filetypes, function(ev)
        vim.treesitter.start(ev.buf)
      end, 'Start tree-sitter')
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    event = { 'BufReadPost', 'BufNewFile' },
  },
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/treesitter.lua
git commit -m "feat: add treesitter lazy spec"
```

### Task 10: Create lua/plugins/lsp.lua

**Files:**
- Create: `lua/plugins/lsp.lua`
- Reference: `plugin/40_plugins.lua` lines 116-251

- [ ] **Step 1: Create the file**

```lua
return {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      vim.lsp.enable({
        'lua_ls', 'pyright', 'odoo_lsp', 'ts_ls', 'eslint',
        'denols', 'jsonls', 'yamlls', 'lemminx', 'astro',
      })
    end,
  },
  { 'b0o/SchemaStore.nvim', lazy = true },
  {
    'mason-org/mason.nvim',
    cmd = 'Mason',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = {
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
    },
    config = function()
      require('mason').setup({ PATH = 'prepend' })
      require('mason-lspconfig').setup({
        ensure_installed = {
          'lua_ls', 'pyright', 'ts_ls', 'eslint',
          'denols', 'jsonls', 'yamlls', 'lemminx', 'astro',
        },
        automatic_installation = true,
      })
      require('mason-tool-installer').setup({
        ensure_installed = { 'stylua', 'black', 'isort', 'prettier' },
        auto_update = true,
      })
    end,
  },
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/lsp.lua
git commit -m "feat: add LSP + mason lazy specs"
```

### Task 11: Create lua/plugins/conform.lua

**Files:**
- Create: `lua/plugins/conform.lua`
- Reference: `plugin/40_plugins.lua` lines 150-190

- [ ] **Step 1: Create the file**

```lua
return {
  'stevearc/conform.nvim',
  event = 'BufWritePost',
  cmd = 'ConformInfo',
  config = function()
    require('conform').setup({
      notify_on_error = false,
      format_after_save = function(bufnr)
        if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
          return
        end
        return { timeout_ms = 2000, lsp_format = 'never' }
      end,
      formatters = {
        black = { prepend_args = { '--fast' } },
      },
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'isort', 'black' },
        javascript = { 'prettier', 'deno_fmt', stop_after_first = true },
        typescript = { 'prettier', 'deno_fmt', stop_after_first = true },
        javascriptreact = { 'prettier', 'deno_fmt', stop_after_first = true },
        typescriptreact = { 'prettier', 'deno_fmt', stop_after_first = true },
        json = { 'prettier', 'deno_fmt', stop_after_first = true },
        yaml = { 'prettier' },
        xml = { 'xmlformatter' },
      },
    })
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/conform.lua
git commit -m "feat: add conform lazy spec"
```

### Task 12: Create lua/plugins/blink.lua

**Files:**
- Create: `lua/plugins/blink.lua`
- Reference: `plugin/40_plugins.lua` lines 289-314

- [ ] **Step 1: Create the file**

```lua
return {
  'saghen/blink.cmp',
  event = { 'InsertEnter', 'CmdlineEnter' },
  build = 'cargo build --release',
  dependencies = { 'rafamadriz/friendly-snippets' },
  config = function()
    require('blink.cmp').setup({
      snippets = { preset = 'mini_snippets' },
    })
    vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })
  end,
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/blink.lua
git commit -m "feat: add blink.cmp lazy spec"
```

### Task 13: Create lua/plugins/editor.lua

**Files:**
- Create: `lua/plugins/editor.lua`
- Reference: `plugin/40_plugins.lua` lines 316-436

- [ ] **Step 1: Create the file**

```lua
return {
  -- Obsidian
  {
    'obsidian-nvim/obsidian.nvim',
    event = {
      'BufReadPre ' .. vim.fn.expand('~') .. '/obsidian/**.md',
      'BufNewFile ' .. vim.fn.expand('~') .. '/obsidian/**.md',
    },
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      workspaces = { { name = 'personal', path = '~/obsidian' } },
      legacy_commands = false,
    },
  },

  -- Render Markdown
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    opts = { file_types = { 'markdown' } },
  },

  -- Diffview
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose' },
    opts = { use_icons = true },
  },

  -- Grug-far (search & replace)
  {
    'MagicDuck/grug-far.nvim',
    cmd = 'GrugFar',
    opts = {},
  },

  -- vim-sleuth (auto detect indent)
  { 'tpope/vim-sleuth', event = { 'BufReadPost', 'BufNewFile' } },

  -- Kulala (HTTP client)
  {
    'mistweaverco/kulala.nvim',
    ft = { 'http', 'rest' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('kulala').setup({
        display_mode = 'float',
        split_direction = 'vertical',
        default_formatters = {
          json = { 'jq', '-r' },
          xml = { 'xmllint', '--format', '-' },
          html = { 'xmllint', '--format', '--html', '-' },
        },
        icons = {
          inlay = { loading = '⏳', done = '✅', error = '❌' },
        },
        additional_curl_options = {},
      })

      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'http', 'rest' },
        callback = function(ev)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = 'Kulala: ' .. desc })
          end
          map('n', '<CR>', require('kulala').run, 'Run request')
          map('n', '<leader>rr', require('kulala').run, 'Run request')
          map('n', '[r', require('kulala').jump_prev, 'Previous request')
          map('n', ']r', require('kulala').jump_next, 'Next request')
          map('n', '<leader>ri', require('kulala').inspect, 'Inspect request')
          map('n', '<leader>rt', require('kulala').toggle_view, 'Toggle headers/body')
          map('n', '<leader>rc', require('kulala').copy, 'Copy as cURL')
          map('n', '<leader>rp', require('kulala').from_curl, 'Paste from cURL')
          map('n', '<leader>ry', require('kulala').copy_response, 'Copy response')
          map('n', '<leader>re', require('kulala').set_selected_env, 'Select environment')
        end,
      })
    end,
  },
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/editor.lua
git commit -m "feat: add editor plugins lazy specs (obsidian, diffview, grug-far, kulala, sleuth)"
```

### Task 14: Create lua/plugins/dap.lua

**Files:**
- Create: `lua/plugins/dap.lua`
- Reference: `plugin/50_dap.lua`

- [ ] **Step 1: Create the file**

Copy the entire DAP config from `plugin/50_dap.lua` into a lazy spec. Replace `MiniDeps.add` calls with lazy `dependencies`.

```lua
return {
  'mfussenegger/nvim-dap',
  cmd = { 'DapContinue', 'DapToggleBreakpoint' },
  keys = {
    { '<F5>', function() require('dap').continue() end, desc = 'Debug: Start/Continue' },
    { '<F9>', function() require('dap').toggle_breakpoint() end, desc = 'Debug: Toggle Breakpoint' },
    { '<leader>dc', function() require('dap').continue() end, desc = 'Debug: Continue (F5)' },
    { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Debug: Toggle Breakpoint (F9)' },
  },
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',
    'theHamsta/nvim-dap-virtual-text',
    'mfussenegger/nvim-dap-python',
    'mxsdev/nvim-dap-vscode-js',
  },
  config = function()
    -- Paste the ENTIRE config function body from plugin/50_dap.lua lines 31-224
    -- (everything inside the later(function() ... end) block, excluding the
    -- MiniDeps.add() calls and the local later/map at the top)
    -- Keep all: dapui.setup, virtual text, auto-open/close, signs,
    -- python/js debuggers, configurations, keymaps
    local dap = require('dap')
    local dapui = require('dapui')

    dapui.setup({
      layouts = {
        {
          elements = {
            { id = 'scopes', size = 0.25 },
            { id = 'breakpoints', size = 0.25 },
            { id = 'stacks', size = 0.25 },
            { id = 'watches', size = 0.25 },
          },
          position = 'right',
          size = 30,
        },
        {
          elements = {
            { id = 'repl', size = 0.5 },
            { id = 'console', size = 0.5 },
          },
          position = 'bottom',
          size = 8,
        },
      },
      floating = {
        border = 'rounded',
        mappings = { close = { 'q', '<Esc>' } },
      },
      mappings = {
        edit = 'e',
        expand = { '<CR>', '<2-LeftMouse>' },
        open = 'o',
        remove = 'd',
        repl = 'r',
        toggle = 't',
      },
    })

    require('nvim-dap-virtual-text').setup()

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    local sign = vim.fn.sign_define
    sign('DapBreakpoint', { text = '', texthl = 'DapBreakpoint', linehl = '', numhl = '' })
    sign('DapBreakpointRejected', { text = '', texthl = 'DapBreakpoint', linehl = '', numhl = '' })
    sign('DapBreakpointCondition', { text = '', texthl = 'DapBreakpointCondition', linehl = '', numhl = '' })
    sign('DapLogPoint', { text = '◆', texthl = 'DapLogPoint', linehl = '', numhl = '' })
    sign('DapStopped', { text = '', texthl = 'DiagnosticSignWarn', linehl = 'Visual', numhl = 'DiagnosticSignWarn' })

    local debugpy_path = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python'
    require('dap-python').setup(debugpy_path)

    require('dap-vscode-js').setup({
      node_path = 'node',
      debugger_path = vim.fn.stdpath('data') .. '/mason/packages/js-debug-adapter',
      adapters = { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'pwa-extensionHost', 'node-terminal' },
    })

    local function is_deno_project()
      local current_file = vim.api.nvim_buf_get_name(0)
      if current_file == '' then return false end
      local current_dir = vim.fn.fnamemodify(current_file, ':h')
      local util = require('lspconfig.util')
      return util.root_pattern('deno.json', 'deno.jsonc')(current_dir) ~= nil
    end

    dap.configurations.javascript = {
      {
        type = 'pwa-node', request = 'launch', name = 'Launch file (Node.js)',
        program = '${file}', cwd = '${workspaceFolder}',
        condition = function() return not is_deno_project() end,
      },
      {
        type = 'pwa-node', request = 'attach', name = 'Attach (Node.js)',
        processId = require('dap.utils').pick_process, cwd = '${workspaceFolder}',
        condition = function() return not is_deno_project() end,
      },
      {
        type = 'pwa-node', request = 'attach', name = 'Attach to React Native (Hermes)',
        port = 8081, cwd = '${workspaceFolder}', sourceMaps = true,
        protocol = 'inspector', localRoot = '${workspaceFolder}', remoteRoot = '${workspaceFolder}',
      },
      {
        type = 'pwa-node', request = 'attach', name = 'Attach to Expo (Metro)',
        port = 19000, cwd = '${workspaceFolder}', sourceMaps = true,
        protocol = 'inspector', localRoot = '${workspaceFolder}', remoteRoot = '${workspaceFolder}',
      },
      {
        type = 'pwa-chrome', request = 'launch', name = 'Debug in Chrome (Expo Web)',
        url = 'http://localhost:19006', webRoot = '${workspaceFolder}', sourceMaps = true,
      },
    }

    dap.configurations.typescript = dap.configurations.javascript
    dap.configurations.typescriptreact = dap.configurations.javascript
    dap.configurations.javascriptreact = dap.configurations.javascript

    local vscode = require('dap.ext.vscode')
    dap.providers.configs['dap.launch.json'] = function(bufnr)
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname == '' then return {} end
      local dir = vim.fn.fnamemodify(bufname, ':p:h')
      local launch_json = vim.fs.find('.vscode/launch.json', { path = dir, upward = true, type = 'file' })[1]
      if not launch_json then return {} end
      return vscode.getconfigs(launch_json)
    end

    -- Remaining keymaps (those not in keys={} above)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { desc = 'Debug: ' .. desc })
    end
    map('v', '<F2>', dapui.eval, 'Evaluate Input')
    map('n', '<S-F5>', dap.terminate, 'Stop')
    map('n', '<C-F5>', dap.restart_frame, 'Restart')
    map('n', '<F6>', dap.pause, 'Pause')
    map('n', '<F7>', dapui.toggle, 'Toggle UI')
    map('n', '<S-F9>', function() dap.set_breakpoint(vim.fn.input('Condition: ')) end, 'Conditional Breakpoint')
    map('n', '<F10>', dap.step_over, 'Step Over')
    map('n', '<F11>', dap.step_into, 'Step Into')
    map('n', '<S-F11>', dap.step_out, 'Step Out')
    map('n', '<leader>du', dapui.toggle, 'Toggle UI (F7)')
    map('n', '<leader>dh', function() require('dap.ui.widgets').hover() end, 'Hover')
    map('n', '<leader>de', dapui.eval, 'Evaluate (F2)')
    map('n', '<leader>da', dap.set_exception_breakpoints, 'Exception Breakpoints')
    map('n', '<leader>dQ', dap.terminate, 'Stop (S-F5)')
    map('n', '<leader>dr', dap.restart, 'Restart (C-F5)')
    map('n', '<leader>dp', dap.pause, 'Pause (F6)')
    map('n', '<leader>dR', dap.repl.toggle, 'Toggle REPL')
    map('n', '<leader>ds', dap.run_to_cursor, 'Run to Cursor')
    map('n', '<leader>dB', dap.clear_breakpoints, 'Clear Breakpoints')
    map('n', '<leader>dC', function() dap.set_breakpoint(vim.fn.input('Condition: ')) end, 'Conditional Breakpoint (S-F9)')
    map('n', '<leader>do', dap.step_over, 'Step Over (F10)')
    map('n', '<leader>di', dap.step_into, 'Step Into (F11)')
    map('n', '<leader>dO', dap.step_out, 'Step Out (S-F11)')
  end,
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/dap.lua
git commit -m "feat: add DAP lazy spec with full debug config"
```

### Task 15: Create lua/plugins/claudecode.lua

**Files:**
- Create: `lua/plugins/claudecode.lua`
- Reference: `plugin/65_claudecode.lua`

- [ ] **Step 1: Create the file**

```lua
return {
  'coder/claudecode.nvim',
  cmd = {
    'ClaudeCode', 'ClaudeCodeFocus', 'ClaudeCodeSend',
    'ClaudeCodeAdd', 'ClaudeCodeTreeAdd',
    'ClaudeCodeDiffAccept', 'ClaudeCodeDiffDeny',
    'ClaudeCodeSelectModel',
  },
  opts = {},
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/claudecode.lua
git commit -m "feat: add claudecode lazy spec"
```

### Task 16: Remove old plugin/ files and verify Phase 1

- [ ] **Step 1: Remove old files**

```bash
rm plugin/10_options.lua plugin/20_keymaps.lua plugin/21_git_flow.lua
rm plugin/30_mini.lua plugin/40_plugins.lua plugin/50_dap.lua plugin/65_claudecode.lua
```

- [ ] **Step 2: Remove old mini.deps data**

```bash
rm -rf ~/.local/share/nvim/site/pack/deps/
```

- [ ] **Step 3: Start Neovim and verify**

```bash
nvim
```

Expected:
- lazy.nvim bootstraps and installs all plugins
- `:Lazy` shows the dashboard with all plugins listed
- No errors in `:messages`
- Statusline, tabline, picker, file explorer all work (still mini.nvim)
- Keymaps work (`<Leader>ff`, `<Leader>ed`, etc.)

- [ ] **Step 4: Commit Phase 1**

```bash
git add -A
git commit -m "feat: Phase 1 complete — migrated from mini.deps to lazy.nvim

All 34 mini modules + carried-over plugins now managed by lazy.nvim.
Old plugin/ files removed. :Lazy dashboard functional."
```

---

## Chunk 3: Phase 2 — UI Shell (lualine + bufferline + noice)

### Task 17: Create lua/plugins/lualine.lua

**Files:**
- Create: `lua/plugins/lualine.lua`

- [ ] **Step 1: Create the file**

```lua
return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  config = function()
    -- Custom component: git branch + ahead/behind + conflicts
    local function git_status()
      local summary = vim.b.minigit_summary_string
      if summary and summary ~= '' then
        return summary
      end
      return ''
    end

    require('lualine').setup({
      options = {
        theme = 'catppuccin',
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        globalstatus = true,
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = {
          { git_status, icon = '' },
          'diff',
          'diagnostics',
        },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location', 'searchcount' },
      },
      inactive_sections = {
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'location' },
      },
    })
  end,
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/lualine.lua
git commit -m "feat: add lualine with catppuccin theme and git status component"
```

### Task 18: Create lua/plugins/bufferline.lua

**Files:**
- Create: `lua/plugins/bufferline.lua`

- [ ] **Step 1: Create the file**

```lua
return {
  'akinsho/bufferline.nvim',
  event = 'VeryLazy',
  opts = {
    options = {
      diagnostics = 'nvim_lsp',
      always_show_bufferline = true,
      separator_style = 'slant',
      show_buffer_close_icons = true,
      show_close_icon = false,
      offsets = {
        {
          filetype = 'snacks_layout_box',
          text = 'File Explorer',
          highlight = 'Directory',
          text_align = 'left',
        },
      },
    },
    highlights = function()
      return require('catppuccin.groups.integrations.bufferline').get()
    end,
  },
}
```

- [ ] **Step 2: Commit**

```bash
git add lua/plugins/bufferline.lua
git commit -m "feat: add bufferline with catppuccin integration"
```

### Task 19: Create lua/plugins/noice.lua

**Files:**
- Create: `lua/plugins/noice.lua`

- [ ] **Step 1: Create the file**

```lua
return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  dependencies = { 'MunifTanjim/nui.nvim' },
  opts = {
    lsp = {
      override = {
        ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
        ['vim.lsp.util.stylize_markdown'] = true,
        ['cmp.entry.get_documentation'] = true,
      },
      progress = { enabled = true },
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
        filter = { event = 'msg_show', kind = '', find = 'written' },
        opts = { skip = true },
      },
    },
  },
}
```

- [ ] **Step 2: Enable catppuccin integration for noice**

Edit `lua/plugins/catppuccin.lua` — add `noice = true` to the integrations table. Do NOT enable `which_key` or `snacks` yet (those plugins are installed in later phases):

```lua
integrations = {
  mason = true,
  mini = { enabled = true, indentscope_color = 'mocha' },
  dap = true,
  noice = true,
  -- which_key = true, -- Phase 4
  -- snacks = true, -- Phase 3a
},
```

Note: `lualine` and `bufferline` integrations are handled by `default_integrations = true` (Catppuccin auto-enables them). The bufferline highlights are explicitly loaded via the `highlights` function in `bufferline.lua`.

- [ ] **Step 3: Remove mini.statusline and mini.tabline from lua/plugins/mini.lua**

In `lua/plugins/mini.lua`, remove these two blocks from the "Step 1: modules needed for first draw" section:

1. The entire `require('mini.statusline').setup({...})` block (with its `content.active` function and `combine_groups` call) — approximately 25 lines starting with the comment `-- Statusline (will be replaced by lualine in Phase 2)`.

2. The `require('mini.tabline').setup()` line (with its comment `-- Tabline (will be replaced by bufferline in Phase 2)`) — 2 lines.

- [ ] **Step 4: Start Neovim and verify**

Expected:
- lualine at bottom with Catppuccin colors, mode, git branch+ahead/behind, diagnostics
- bufferline at top with buffer tabs, icons, slant separators
- noice: floating cmdline when pressing `:`, styled messages
- No errors in `:messages`

- [ ] **Step 5: Commit Phase 2**

```bash
git add lua/plugins/noice.lua lua/plugins/catppuccin.lua lua/plugins/mini.lua
git commit -m "feat: add noice.nvim, enable catppuccin integration, remove mini statusline/tabline

Phase 2 complete — modern UI shell with lualine + bufferline + noice."
```

---

## Chunk 4: Phase 3a+3b — snacks.nvim (UI Replacements + New Features)

### Task 20: Create lua/plugins/snacks.lua (replacement modules)

**Files:**
- Create: `lua/plugins/snacks.lua`

- [ ] **Step 1: Create the file**

```lua
return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    -- Replacements for mini modules
    dashboard = {
      enabled = true,
      preset = {
        keys = {
          { icon = ' ', key = 'f', desc = 'Find File', action = ':lua Snacks.picker.files()' },
          { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
          { icon = ' ', key = 'g', desc = 'Find Text', action = ':lua Snacks.picker.grep()' },
          { icon = ' ', key = 'r', desc = 'Recent Files', action = ':lua Snacks.picker.recent()' },
          { icon = ' ', key = 's', desc = 'Restore Session', action = ':lua MiniSessions.select("read")' },
          { icon = '󰒲 ', key = 'L', desc = 'Lazy', action = ':Lazy' },
          { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
        },
        header = [[
 ███╗   ██╗██╗   ██╗██╗███╗   ███╗
 ████╗  ██║██║   ██║██║████╗ ████║
 ██╔██╗ ██║██║   ██║██║██╔████╔██║
 ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
 ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
 ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝]],
      },
    },
    notifier = { enabled = true, timeout = 3000 },
    picker = { enabled = true },
    explorer = { enabled = true },
    indent = { enabled = true, animate = { enabled = true } },
    scroll = { enabled = true, animate = { duration = { step = 15, total = 250 } } },
    bufdelete = { enabled = true },
    words = { enabled = true },

    -- New features (Phase 3b)
    animate = { enabled = true },
    zen = { enabled = true },
    dim = { enabled = true },
    image = { enabled = true },
    input = { enabled = true },
    rename = { enabled = true },
    lazygit = { enabled = true },
    terminal = { enabled = true },
    statuscolumn = { enabled = true },
    toggle = { enabled = true },

    -- Styles
    styles = {},
  },
  keys = {
    -- Dashboard
    { '<leader>eo', function() Snacks.dashboard() end, desc = 'Dashboard' },

    -- Picker (replacing mini.pick mappings)
    { '<leader>ff', function() Snacks.picker.files({ cwd = require('utils.root').project_root() }) end, desc = 'Files (global)' },
    { '<leader>fF', function() Snacks.picker.files() end, desc = 'Files (local)' },
    { '<leader>fg', function() Snacks.picker.grep({ cwd = require('utils.root').project_root() }) end, desc = 'Grep (global)' },
    { '<leader>fG', function() Snacks.picker.grep() end, desc = 'Grep (local)' },
    { '<leader>fb', function() Snacks.picker.buffers() end, desc = 'Buffers' },
    { '<leader>fh', function() Snacks.picker.help() end, desc = 'Help tags' },
    { '<leader>fr', function() Snacks.picker.resume() end, desc = 'Resume' },
    { '<leader>fd', function() Snacks.picker.diagnostics() end, desc = 'Diagnostics workspace' },
    { '<leader>fD', function() Snacks.picker.diagnostics_buffer() end, desc = 'Diagnostics buffer' },
    { '<leader>fc', function() Snacks.picker.git_log() end, desc = 'Commits (all)' },
    { '<leader>fC', function() Snacks.picker.git_log({ current_file = true }) end, desc = 'Commits (buf)' },
    { '<leader>fs', function() Snacks.picker.lsp_symbols() end, desc = 'Symbols workspace' },
    { '<leader>fS', function() Snacks.picker.lsp_symbols({ filter = { kind = 'Function' } }) end, desc = 'Symbols document' },
    { '<leader>fR', function() Snacks.picker.lsp_references() end, desc = 'References (LSP)' },
    { '<leader>fl', function() Snacks.picker.lines() end, desc = 'Lines (buf)' },
    { '<leader>fw', function() Snacks.picker.grep_word() end, desc = 'Grep current word' },
    { '<leader>fH', function() Snacks.picker.highlights() end, desc = 'Highlight groups' },
    { '<leader>f/', function() Snacks.picker.search_history() end, desc = '"/" history' },
    { '<leader>f:', function() Snacks.picker.command_history() end, desc = '":" history' },
    { '<leader>fv', function() Snacks.picker.recent() end, desc = 'Recent files' },

    -- Explorer (replacing mini.files)
    { '<leader>ed', function() Snacks.explorer() end, desc = 'Explorer (cwd)' },
    { '<leader>ef', function() Snacks.explorer({ cwd = vim.fn.expand('%:p:h') }) end, desc = 'Explorer (file dir)' },

    -- Notifications history (replacing mini.notify)
    { '<leader>en', function() Snacks.notifier.show_history() end, desc = 'Notifications' },

    -- Buffer delete (replacing mini.bufremove)
    { '<leader>bd', function() Snacks.bufdelete() end, desc = 'Delete' },
    { '<leader>bD', function() Snacks.bufdelete.other() end, desc = 'Delete others' },

    -- Words navigation
    { ']]', function() Snacks.words.jump(1) end, desc = 'Next reference', mode = { 'n', 'x' } },
    { '[[', function() Snacks.words.jump(-1) end, desc = 'Prev reference', mode = { 'n', 'x' } },

    -- New features
    { '<leader>oz', function() Snacks.zen() end, desc = 'Zen mode' },
    { '<leader>od', function() Snacks.dim() end, desc = 'Dim toggle' },
    { '<leader>tg', function() Snacks.lazygit() end, desc = 'Lazygit' },
    { '<leader>tf', function() Snacks.terminal() end, desc = 'Terminal (float)' },
    { '<leader>lr', function() Snacks.rename.rename_file() end, desc = 'Rename file' },
  },
  init = function()
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Setup toggles
        Snacks.toggle.option('spell', { name = 'Spelling' }):map('\\s')
        Snacks.toggle.option('wrap', { name = 'Wrap' }):map('\\w')
        Snacks.toggle.option('relativenumber', { name = 'Relative Number' }):map('\\r')
        Snacks.toggle.diagnostics():map('\\d')
        Snacks.toggle.inlay_hints():map('\\h')
      end,
    })
  end,
}
```

- [ ] **Step 2: Remove replaced mini modules from lua/plugins/mini.lua**

Remove from `lua/plugins/mini.lua`:
- `require('mini.notify').setup(...)` block
- `require('mini.starter').setup()`
- `require('mini.extra').setup()`
- `require('mini.bufremove').setup()`
- `require('mini.cursorword').setup()`
- `require('mini.files').setup(...)` block (and its autocmds)
- `require('mini.indentscope').setup()`
- `require('mini.map').setup(...)` block (and the n/N/*/# remaps)
- `require('mini.pick').setup()` block

Keep everything else (ai, align, clue, comment, diff, git, hipatterns, jump, jump2d, keymap, move, operators, pairs, snippets, splitjoin, surround, trailspace, visits, basics, icons, misc, sessions).

- [ ] **Step 3: Update keymaps in lua/config/keymaps.lua**

Remove mappings that are now handled by snacks.lua `keys = {}`:
- All `<leader>f*` pick mappings (lines 208-239)
- `<leader>ed`, `<leader>ef` explorer mappings
- `<leader>en` notification history
- `<leader>bd`, `<leader>bw` buffer delete mappings (keep `<leader>ba`, `<leader>bs`)
- `<leader>mt`, `<leader>mf`, `<leader>ms`, `<leader>mr` map mappings
- `<leader>tf`, `<leader>tg`, `<leader>td` terminal mappings (keep `<leader>tT`, `<leader>tt`)
- Toggle mappings now handled by snacks.toggle init function: `\s` (spell), `\w` (wrap), `\r` (relative number), `\d` (diagnostics), `\h` (inlay hints)

Keep all other mappings (git, language, session, visits, AI, replace, etc.)

- [ ] **Step 4: Delete replaced utils and stub pick-utils**

```bash
rm lua/utils/float-term.lua lua/utils/toggle.lua
```

`pick-utils.lua` depends on `MiniPick` which was removed in Step 2. Add a deprecation guard at the top of `pick-utils.lua` so it fails gracefully instead of erroring:

```lua
-- TODO: Rewrite pickers for snacks.picker API (deferred from Phase 3a)
-- All pick-utils functions are currently non-functional after mini.pick removal.
-- The keymaps that used these have been replaced by snacks.picker keymaps in snacks.lua.
local M = {}
return M
```

Replace the entire file content with this stub. The original logic (git commands, path resolution) will be reimplemented incrementally using `Snacks.picker()` in follow-up commits.

- [ ] **Step 4b: Enable Catppuccin snacks integration**

Edit `lua/plugins/catppuccin.lua` — uncomment `snacks = true` in the integrations table:

```lua
integrations = {
  mason = true,
  mini = { enabled = true, indentscope_color = 'mocha' },
  dap = true,
  noice = true,
  snacks = true,
  -- which_key = true, -- Phase 4
},
```

- [ ] **Step 5: Start Neovim and verify**

Expected:
- snacks.dashboard shows on `nvim` (ASCII art header + quick keys)
- `<leader>ff` opens snacks.picker for files
- `<leader>ed` opens snacks.explorer (tree view)
- Notifications use snacks.notifier (animated)
- Indent guides animated
- Smooth scroll on `<C-d>`/`<C-u>`
- `<leader>tg` opens lazygit in floating terminal
- `<leader>oz` enters zen mode
- No errors in `:messages`

- [ ] **Step 6: Commit Phase 3a+3b**

```bash
git add -A
git commit -m "feat: Phase 3 complete — snacks.nvim replaces mini UI + new features

Replaced: dashboard, notifier, picker, explorer, indent, scroll, bufdelete, words.
Added: animate, zen, dim, image, input, rename, lazygit, terminal, statuscolumn, toggle."
```

---

## Chunk 5: Phase 4 — which-key + Phase 5 — Cleanup

### Task 21: Create lua/plugins/which-key.lua

**Files:**
- Create: `lua/plugins/which-key.lua`

- [ ] **Step 1: Create the file**

```lua
return {
  'folke/which-key.nvim',
  event = 'VeryLazy',
  opts = {
    preset = 'helix',
    spec = {
      { '<leader>a', group = 'AI (Claude Code)', icon = '🤖' },
      { '<leader>b', group = 'Buffer' },
      { '<leader>d', group = 'Debug', icon = '' },
      { '<leader>e', group = 'Explore/Edit' },
      { '<leader>f', group = 'Find', icon = '🔍' },
      { '<leader>g', group = 'Git', icon = '' },
      { '<leader>gc', group = 'Conflict' },
      { '<leader>gf', group = 'Flow' },
      { '<leader>gff', group = 'Feature' },
      { '<leader>gfr', group = 'Release' },
      { '<leader>gfh', group = 'Hotfix' },
      { '<leader>gfb', group = 'Bugfix' },
      { '<leader>l', group = 'Language', icon = '' },
      { '<leader>n', group = 'Notes (Obsidian)', icon = '📝' },
      { '<leader>o', group = 'Other' },
      { '<leader>r', group = 'Replace', icon = '' },
      { '<leader>s', group = 'Session' },
      { '<leader>t', group = 'Terminal' },
      { '<leader>v', group = 'Visits' },
    },
  },
}
```

- [ ] **Step 2: Remove mini.clue from lua/plugins/mini.lua**

Remove the entire `miniclue.setup(...)` block from `lua/plugins/mini.lua`.

- [ ] **Step 3: Remove leader_group_clues from lua/config/keymaps.lua**

Remove the `_G.Config.leader_group_clues` table. which-key.nvim handles this now.

- [ ] **Step 3b: Enable Catppuccin which-key integration**

Edit `lua/plugins/catppuccin.lua` — uncomment `which_key = true`:

```lua
integrations = {
  mason = true,
  mini = { enabled = true, indentscope_color = 'mocha' },
  dap = true,
  noice = true,
  snacks = true,
  which_key = true,
},
```

- [ ] **Step 4: Verify (including mini.keymap conflict check)**

This is a spec risk item: both `mini.keymap` and which-key intercept keymap events.

Expected:
- Press `<Leader>` and wait — which-key popup appears with groups and icons
- All key sequences work as before (especially multi-key sequences like `<Leader>gc*`, `<Leader>gf*`)
- `mini.keymap` mappings (if any remain) still trigger correctly
- No errors in `:messages`
- No duplicate or phantom key entries in which-key popup

- [ ] **Step 5: Commit Phase 4**

```bash
git add -A
git commit -m "feat: Phase 4 complete — which-key replaces mini.clue for key hints"
```

### Task 22: Phase 5 — Final cleanup

- [ ] **Step 1: Delete obsolete plugin/ files**

These files have been replaced by `lua/config/` and `lua/plugins/`:

```bash
rm -f plugin/10_options.lua plugin/20_keymaps.lua plugin/21_git_flow.lua plugin/30_mini.lua plugin/40_plugins.lua plugin/50_dap.lua plugin/65_claudecode.lua
rmdir plugin/
```

- [ ] **Step 2: Remove orphaned plugin directories and mini-deps-snap**

```bash
rm -rf ~/.local/share/nvim/site/pack/
rm -f mini-deps-snap
```

- [ ] **Step 3: Verify file structure matches spec**

```bash
find lua/ -name '*.lua' | sort
```

Expected output:
```
lua/config/autocmds.lua
lua/config/keymaps.lua
lua/config/options.lua
lua/plugins/blink.lua
lua/plugins/bufferline.lua
lua/plugins/catppuccin.lua
lua/plugins/claudecode.lua
lua/plugins/conform.lua
lua/plugins/dap.lua
lua/plugins/editor.lua
lua/plugins/lsp.lua
lua/plugins/lualine.lua
lua/plugins/mini.lua
lua/plugins/noice.lua
lua/plugins/snacks.lua
lua/plugins/treesitter.lua
lua/plugins/which-key.lua
lua/utils/git-conflict.lua
lua/utils/git-flow.lua
lua/utils/git.lua
lua/utils/kitty-nav.lua
lua/utils/pick-utils.lua
lua/utils/project-session.lua
lua/utils/root.lua
lua/utils/tailwind-colors.lua
```

- [ ] **Step 4: Profile startup time**

```bash
nvim --startuptime /tmp/startup.log
# Then inside Neovim: :Lazy profile
```

- [ ] **Step 5: Verify Catppuccin integrations**

Open Neovim and verify Catppuccin colors render correctly across all integrated plugins:
- lualine: mode section uses Catppuccin palette colors (not default green/blue)
- bufferline: tab backgrounds use Catppuccin surface colors
- noice: cmdline and messages use Catppuccin accent colors
- which-key: popup uses Catppuccin background/text colors
- snacks: dashboard, notifier, picker, indent all use Catppuccin highlights
- mini: diff signs, git signs use Catppuccin palette

If any plugin uses default/fallback colors, check `lua/plugins/catppuccin.lua` integrations table.

- [ ] **Step 6: Full verification**

Open Neovim and verify:
- Dashboard shows with ASCII art on `nvim`
- `<leader>ff` picks files with snacks.picker
- `<leader>ed` opens snacks.explorer
- Statusline shows mode/git/diagnostics with lualine
- Bufferline shows tabs with icons
- `:` opens floating cmdline (noice)
- `<leader>` shows which-key popup
- `<leader>tg` opens lazygit
- `<leader>oz` enters zen mode
- `<C-d>`/`<C-u>` smooth scroll
- Indent guides animate
- `<F5>` starts debugger
- LSP works (hover, go-to-def, diagnostics)
- Format on save works
- Git branch + ahead/behind in statusline
- Colors are cohesive — all plugins use Catppuccin palette, no jarring default colors
- No errors in `:messages`

- [ ] **Step 7: Final commit**

```bash
git add -u  # stages deletions of plugin/ files and mini-deps-snap
git commit -m "feat: Phase 5 complete — cleanup and polish

Migration from mini.deps to lazy.nvim complete.
12 mini UI modules replaced with snacks/lualine/bufferline/noice/which-key.
10 new features added. 22 mini modules retained.
Config restructured: modular lua/plugins/ with one spec per plugin."
```

---

## Notes

### pick-utils.lua Migration (HIGH RISK — deferred)

`pick-utils.lua` is stubbed out in Phase 3a (Task 20 Step 4). The original 16KB of custom pickers using mini.pick API needs to be reimplemented using `Snacks.picker()` API in follow-up commits. The utility logic (git commands, path resolution) is picker-agnostic and can be reused. The risk is in the picker source/action definitions which have different API shapes.

Priority pickers to reimplement first: `global_files`, `global_grep`, `git_branch_files`.

### Rollback

If any phase breaks the editor:
```bash
git log --oneline  # find last good commit
git reset --hard <commit-hash>
```

Or return to main:
```bash
git checkout main
```

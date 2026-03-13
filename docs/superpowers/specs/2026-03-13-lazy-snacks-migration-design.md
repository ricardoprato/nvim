# Migration: mini.deps → lazy.nvim + snacks.nvim UI Modernization

## Goal

Modernize the Neovim config's UI/UX with a cohesive, animated, modern look. Migrate from mini.deps to lazy.nvim as package manager. Replace mini.nvim UI modules with snacks.nvim + premium UI plugins (lualine, bufferline, noice, which-key) where they offer a better visual experience. Keep mini.nvim for text manipulation and areas without a better alternative.

## Decisions

- **Package manager**: lazy.nvim (lazy-loading, UI dashboard, profiling, ecosystem compatibility)
- **UI strategy**: Prefer snacks.nvim for all UI surfaces; supplement with lualine, bufferline, noice, which-key
- **Dashboard style**: Visually striking — ASCII art, animations, colors (snacks.dashboard)
- **Colorscheme**: Keep Catppuccin — all new plugins have native Catppuccin support
- **mini.nvim**: Stays installed as a lazy.nvim dependency for the 22 modules that have no better alternative
- **Icons**: Keep `mini.icons` with its `nvim-web-devicons` mock — all new plugins (lualine, bufferline, snacks) work with the mock, no need to install nvim-web-devicons separately
- **`_G.Config` pattern**: Drop `now_if_args` (replaced by lazy.nvim `event`/`cmd`/`ft` keys). Keep `_G.Config.initial_cwd` and `_G.Config.new_autocmd` as they are used by utils and autocmds independently of the package manager

## Feature Map

### Replacements (12 mini modules removed)

| Function | Current (mini) | New | Improvement |
|----------|---------------|-----|-------------|
| Dashboard | mini.starter | snacks.dashboard | Animated ASCII art, flexible sections, colors |
| Notifications | mini.notify | snacks.notifier | Entry/exit animations, icons, history |
| Picker | mini.pick + mini.extra | snacks.picker | Rich previews, flexible layouts, themed |
| File Explorer | mini.files | snacks.explorer | Tree view, git status icons, inline actions |
| Indent Guides | mini.indentscope | snacks.indent | Guides + animated scope, chunk highlighting |
| Minimap → Smooth Scroll | mini.map (code minimap) | snacks.scroll | Replaces bird's-eye minimap with smooth scrolling animation + minimal scrollbar. Deliberate feature swap — minimap dropped in favor of scroll UX |
| Statusline | mini.statusline | lualine.nvim | Sections with separators, icons, Catppuccin theme |
| Tabline | mini.tabline | bufferline.nvim | Tabs with icons, colors by type, close buttons |
| Key Hints | mini.clue | which-key.nvim | Styled popup, grouping, icons |
| Cmdline + Messages | (builtin) | noice.nvim | Floating cmdline, styled messages, LSP progress |
| Buffer Delete | mini.bufremove | snacks.bufdelete | Same function, integrated in snacks |
| Word Highlight | mini.cursorword | snacks.words | Highlight + LSP reference navigation |

Note: mini.pick and mini.extra count as 2 modules. Total configured mini modules: 34 (12 replaced + 22 retained).

### New Features (7 new + 3 replacing custom utils)

| Plugin | Function |
|--------|----------|
| snacks.animate | Animation engine for scroll, resize, window transitions |
| snacks.zen | Zen mode — hide UI to focus on code |
| snacks.dim | Dim code outside current scope |
| snacks.image | Inline images in terminal (Kitty protocol) |
| snacks.input | Styled vim.ui.input (rename, etc.) |
| snacks.rename | LSP rename + automatic file rename |
| snacks.lazygit | Lazygit in floating terminal |
| snacks.terminal | Terminal management (replaces float-term.lua) |
| snacks.statuscolumn | Custom status column (numbers, signs, folds) |
| snacks.toggle | Unified toggles (replaces toggle.lua) |

### Retained mini.nvim Modules (22)

ai, surround, operators, pairs, align, move, splitjoin, comment, jump, jump2d, bracketed, diff, git, hipatterns, sessions, visits, snippets, trailspace, misc, basics, icons, keymap

### Carried-Over Plugins (not changing)

All existing non-mini plugins migrate into their respective lazy spec files:
- treesitter + textobjects, nvim-lspconfig, mason + mason-lspconfig + mason-tool-installer
- blink.cmp, friendly-snippets, SchemaStore.nvim, conform.nvim, vim-sleuth
- nvim-dap + nvim-dap-ui + nvim-nio + nvim-dap-virtual-text + nvim-dap-python + nvim-dap-vscode-js
- diffview.nvim, grug-far.nvim, obsidian.nvim (+ plenary.nvim dep), render-markdown.nvim, kulala.nvim (+ plenary.nvim dep)
- claudecode.nvim, catppuccin/nvim

### Orphaned Plugins (in mini-deps-snap but unused in config)

These entries exist in `mini-deps-snap` but are not referenced in any config file. They will not be carried over:
- avante.nvim, copilot.lua, img-clip.nvim, codecompanion.nvim, codecompanion-history.nvim

Their installed directories under `site/pack/deps/` should be cleaned up in Phase 5.

## File Architecture

### Current Structure

```
init.lua              ← bootstrap mini.deps + _G.Config
plugin/
  10_options.lua      ← vim options
  20_keymaps.lua      ← all keymaps (400+ lines)
  21_git_flow.lua     ← :GitFlow user command
  30_mini.lua         ← 34 modules in 1 file (1000+ lines)
  40_plugins.lua      ← all non-mini plugins
  50_dap.lua          ← debugging
  65_claudecode.lua   ← claude
lua/utils/            ← utility modules
after/                ← ftplugin, lsp, snippets
```

### New Structure

```
init.lua              ← bootstrap lazy.nvim + _G.Config (initial_cwd, new_autocmd)
lua/
  config/
    options.lua       ← vim options
    keymaps.lua       ← base keymaps + :GitFlow command
    autocmds.lua      ← extracted autocommands
  plugins/            ← 1 file per plugin/group (lazy specs)
    snacks.lua        ← snacks.nvim (all modules)
    mini.lua          ← 22 retained mini modules
    lualine.lua       ← statusline
    bufferline.lua    ← tabline
    noice.lua         ← cmdline & messages
    which-key.lua     ← key hints
    catppuccin.lua    ← colorscheme
    treesitter.lua    ← treesitter + textobjects
    lsp.lua           ← nvim-lspconfig + mason
    conform.lua       ← formatting
    blink.lua         ← completion
    dap.lua           ← debugging (6 plugins)
    claudecode.lua    ← claude code
    editor.lua        ← diffview, grug-far, obsidian, render-markdown, kulala, sleuth
  utils/              ← kept (cleaned up)
    git-conflict.lua
    git-flow.lua
    git.lua
    kitty-nav.lua
    pick-utils.lua    ← adapted for snacks.picker (HIGH RISK — see notes)
    project-session.lua
    root.lua
    tailwind-colors.lua
after/                ← kept as-is (ftplugin, lsp, snippets)
```

Key change: from 2 monolithic files (30_mini.lua + 40_plugins.lua) to modular per-plugin files. Each lazy spec is self-contained with config, keymaps, and lazy-loading in one place.

## Migration Phases

Each phase leaves the editor fully functional. Can pause or revert between phases. Each phase gets its own commit (or set of commits); reverting means `git reset` to the last phase-end commit.

### Phase 0: Preparation

1. Commit current uncommitted changes (root.lua io.popen fix, git.lua fix, conform format_after_save)
2. Create branch `feat/lazy-migration`
3. Add `.superpowers/` and `docs/` to `.gitignore`
4. Create `lua/config/` — extract options, keymaps, autocmds from `plugin/`
5. Move `:GitFlow` command from `plugin/21_git_flow.lua` into `lua/config/keymaps.lua`
6. Create empty `lua/plugins/`

### Phase 1: Package Manager (mini.deps → lazy.nvim)

1. Rewrite `init.lua` with lazy.nvim bootstrap (keep `_G.Config.initial_cwd` and `_G.Config.new_autocmd`, drop `now_if_args`)
2. Convert all `add()` / `now()` / `later()` calls to lazy plugin specs with appropriate `event`/`cmd`/`ft`/`lazy` keys
3. Migrate mini.nvim to individual module specs (all 34 modules initially, pruning happens in later phases)
4. Migrate existing plugins (treesitter, LSP, conform, blink, etc.) with their `dependencies` wired (e.g., obsidian → plenary, dap-ui → nvim-nio)
5. **Result**: Same editor, new package manager — `:Lazy` works

### Phase 2: UI Shell (statusline + tabline + cmdline)

1. Install and configure `lualine.nvim` with Catppuccin theme and integration enabled in Catppuccin config
2. Install and configure `bufferline.nvim` with Catppuccin and integration enabled
3. Install and configure `noice.nvim` (floating cmdline, LSP progress) with Catppuccin integration enabled
4. Remove `mini.statusline` and `mini.tabline`
5. Migrate statusline git summary (ahead/behind) to lualine custom component
6. **Result**: Modern statusline, tabline, and cmdline

### Phase 3a: snacks.nvim — UI Replacements

1. Install snacks.nvim
2. Configure replacement modules: dashboard, notifier, picker, explorer, indent, scroll, bufdelete, words
3. Enable Catppuccin integrations for snacks in catppuccin config
4. Remove replaced mini modules (starter, notify, pick, extra, files, indentscope, map, bufremove, cursorword)
5. Adapt `pick-utils.lua` for snacks.picker API — **high-risk item**: this is 16KB of custom pickers with mini.pick-specific API (different function signatures, source definitions, action handling). May need significant rewrite or partial reimplementation.
6. Replace `float-term.lua` with snacks.terminal
7. Replace `toggle.lua` with snacks.toggle
8. **Result**: Core UI using snacks — cohesive look

### Phase 3b: snacks.nvim — New Features

1. Enable new snacks modules: animate, zen, dim, image, input, rename, lazygit, terminal, statuscolumn, toggle
2. Add keymaps for new features (zen toggle, lazygit, dim, etc.)
3. **Result**: Full snacks feature set active

### Phase 4: which-key.nvim + Keymaps

1. Install `which-key.nvim` with groups and icons
2. Migrate descriptions from `mini.clue`
3. Verify no conflicts between `mini.keymap` and which-key's keymap interception
4. Move plugin-specific keymaps into their respective lazy specs
5. Remove `mini.clue`
6. **Result**: Modern key hints and colocated keymaps

### Phase 5: Cleanup & Polish

1. Delete obsolete files (`plugin/30_mini.lua`, `plugin/40_plugins.lua`, `plugin/10_options.lua`, `plugin/20_keymaps.lua`, `plugin/21_git_flow.lua`, `mini-deps-snap`)
2. Delete replaced utils (`float-term.lua`, `toggle.lua`)
3. Clean up orphaned plugin directories under `site/pack/deps/` (avante.nvim, copilot.lua, img-clip.nvim)
4. Verify all Catppuccin integrations are enabled and rendering correctly
5. Adjust highlights and colors for cohesion
6. Profile startup time with `:Lazy profile`
7. **Result**: Clean, modern, cohesive config

## Safety Strategy

- Everything on branch `feat/lazy-migration` — main stays intact
- Each phase ends with a working commit — can pause or revert via `git reset` to last phase-end commit
- Keymaps stay identical — only the backend changes
- mini.nvim stays installed as a lazy.nvim dependency (not deleted)

## Risk Items

- **`pick-utils.lua` migration (Phase 3a)**: Largest utility file (~16KB). mini.pick and snacks.picker have significantly different APIs (function signatures, source definitions, action handling). May require substantial rewrite. Consider reimplementing pickers incrementally rather than all at once.
- **`mini.keymap` + which-key conflict (Phase 4)**: Both intercept keymap events. Test thoroughly before committing.
- **noice.nvim stability**: noice.nvim overrides core Neovim UI (cmdline, messages). Can occasionally conflict with other plugins. Test with all features enabled.

## Files Deleted at End

- `plugin/10_options.lua` → `lua/config/options.lua`
- `plugin/20_keymaps.lua` → `lua/config/keymaps.lua`
- `plugin/21_git_flow.lua` → `lua/config/keymaps.lua` (merged)
- `plugin/30_mini.lua` → `lua/plugins/mini.lua` + `lua/plugins/snacks.lua`
- `plugin/40_plugins.lua` → split across `lua/plugins/*.lua`
- `plugin/50_dap.lua` → `lua/plugins/dap.lua`
- `plugin/65_claudecode.lua` → `lua/plugins/claudecode.lua`
- `lua/utils/float-term.lua` → replaced by snacks.terminal
- `lua/utils/toggle.lua` → replaced by snacks.toggle
- `mini-deps-snap` → lazy-lock.json (lazy.nvim equivalent)

## Dependencies

New plugins to install:
- `folke/lazy.nvim` (package manager)
- `folke/snacks.nvim` (UI framework)
- `nvim-lualine/lualine.nvim` (statusline)
- `akinsho/bufferline.nvim` (tabline)
- `folke/noice.nvim` (cmdline/messages)
- `folke/which-key.nvim` (key hints)
- `MunifTanjim/nui.nvim` (noice dependency — needs fresh install, previously only in snap for removed avante.nvim)

Carried-over dependencies (already installed, wired into new lazy specs):
- `nvim-lua/plenary.nvim` (dep of obsidian.nvim, kulala.nvim)
- All treesitter, LSP, DAP, completion, and editor plugins listed in Carried-Over Plugins section

All new plugins have native Catppuccin integration.

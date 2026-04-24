# Neovim Config

Personal polyglot Neovim configuration. Project workflow managed via **GSD** (Get Shit Done) under `.planning/`.

## Project

Swiss-army editor for Odoo 17/18/19 (Python + XML + OWL/JS) plus frontend frameworks (Astro, Next.js, React) and Docker. Brownfield config undergoing a cohesion pass — see `.planning/PROJECT.md` for full context.

**Core Value:** Open any project anywhere on disk and be instantly productive — no per-path configuration.

## Planning Artifacts (local, not versioned)

`.planning/` is gitignored (per user preference `commit_docs: false`). Artifacts live locally:

- `.planning/PROJECT.md` — project context, locked constraints, active requirements
- `.planning/REQUIREMENTS.md` — 20 v1 requirements across FOUND/NAV/GIT/KMAP categories
- `.planning/ROADMAP.md` — 4-phase plan (Foundation → Project-Agnostic Flow → Git Surface → Keymap Remediation)
- `.planning/STATE.md` — project memory / current phase pointer
- `.planning/codebase/` — auto-generated codebase map (STACK/ARCHITECTURE/STRUCTURE/CONVENTIONS/INTEGRATIONS/TESTING/CONCERNS)
- `.planning/research/` — project-level research (STACK/FEATURES/ARCHITECTURE/PITFALLS/SUMMARY)
- `.planning/config.json` — workflow settings (YOLO mode, standard granularity, parallel execution, quality model profile)

## Workflow

Use GSD slash commands to progress through the roadmap:

- **Next step:** `/gsd-plan-phase 1` — produce the detailed plan for Phase 1 (Foundation)
- **After plan:** `/gsd-execute-phase 1` — execute all plans in the phase
- **Progress check:** `/gsd-progress` — show status, route to next action
- **Resume after break:** `/gsd-resume-work`

Do not skip discuss/plan/execute stages for Phase 1+. For trivial tweaks outside the roadmap, `/gsd-fast` or `/gsd-quick` are acceptable.

## Locked Constraints

These come from `.planning/PROJECT.md` and must hold through this milestone:

- **Runtime:** Neovim 0.11+ — uses `vim.lsp.enable` table form + `after/lsp/<server>.lua` convention; do not regress
- **Core stack locked:** `lazy.nvim`, `mini.nvim`, `snacks.nvim` — do not propose replacing
- **Integration locked:** `claudecode.nvim` works well — preserve unchanged throughout this milestone
- **No new plugin additions** required for any v1 requirement — the research proved all three capabilities ship from the already-installed stack
- **Explicit anti-features** (research-confirmed): no `gitsigns`, no `neogit`, no `vim-fugitive`, no `legendary.nvim` (archived 2025-04-17), no auto-VimEnter session restore, no auto-cd on file open, no terminals in session, no per-project LSP swaps

## Architecture Quick Reference

```
nvim/
├── init.lua                  # Bootstrap lazy.nvim, seed _G.Config
├── lua/config/               # Core: options, keymaps, autocmds
├── lua/plugins/              # lazy.nvim specs (auto-imported)
├── lua/utils/                # Shared helpers (git, git-flow, kitty-nav, tailwind-colors)
├── after/ftplugin/           # Per-filetype buffer setup
├── after/lsp/                # Per-server vim.lsp.Config overrides (0.11+ native)
└── after/snippets/           # Language-scoped snippet overrides
```

**Leader-key namespace:** `<leader>b`=Buffer, `<leader>e`=Edit, `<leader>f`=Find, `<leader>g`=Git, `<leader>gf*`=GitFlow, `<leader>l`=LSP, `<leader>n`=Notes/Obsidian, `<leader>r`=Replace, `<leader>s`=Session, `<leader>t`=Terminal, `<leader>d`=Debug, `<leader>a`=AI/Claude, `<leader>v`=Visits, `<leader>o`=Other toggles, `<leader>u`=UI (to be declared in Phase 4).

## Known Issues (tracked in CONCERNS.md, addressed opportunistically)

- `<leader>rr` triple-mapped (grug-far + kulala ftplugin) — documented as intentional in Phase 4
- `<leader>u` group used but undeclared — fixed in Phase 4
- Duplicate `Snacks.toggle.dim()` creation — fixed in Phase 4
- Stale `<leader>ek/em/ep` pointers at empty `plugin/` dir — fixed in Phase 4
- Sync `io.popen` in `utils/git.lua` — fixed in Phase 1 (async port prereq)

## Validation Posture

No test harness. Validate via:

- `:checkhealth` and `:checkhealth which-key`
- `:Lazy profile` (startup timing)
- `:LspInfo`, `:Mason`, `:LspLog`
- Manual smoke: open a real Odoo addon + a real Astro project, exercise session swap, verify LSP attach

---
*Managed by GSD. Run `/gsd-progress` to see current status.*

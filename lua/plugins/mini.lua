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

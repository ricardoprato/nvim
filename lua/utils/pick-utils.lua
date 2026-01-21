local M = {}
local root = require('utils.root')

--- Global file picker
-- Busca archivos desde donde se abrió Neovim
function M.global_files()
  local MiniPick = require 'mini.pick'
  MiniPick.builtin.files({}, { source = { cwd = root.global_root() } })
end

--- Multi-grep with file type shortcuts
-- Permite buscar texto y filtrar por tipo de archivo separando con doble espacio
-- Ejemplo: "pattern  l" busca "pattern" solo en archivos *.lua
-- Shortcuts disponibles:
--   l = *.lua, v = *.vim, n = *.{vim,lua}, c = *.c, r = *.rs
--   g = *.go, p = *.py, x = *.xml, t = *.ts, j = *.js, m = *.md
function M.multi_grep(opts)
  opts = opts or {}
  local cwd = opts.cwd or root.project_root() or vim.fn.getcwd()

  -- Shortcuts de tipo de archivo (igual que en telescope)
  local shortcuts = opts.shortcuts or {
    ['l'] = '*.lua',
    ['v'] = '*.vim',
    ['n'] = '*.{vim,lua}',
    ['c'] = '*.c',
    ['r'] = '*.rs',
    ['g'] = '*.go',
    ['p'] = '*.py',
    ['x'] = '*.xml',
    ['t'] = '*.ts',
    ['j'] = '*.js',
    ['m'] = '*.md',
  }

  local MiniPick = require 'mini.pick'
  local process

  local set_items_opts = { do_match = false }
  local spawn_opts = { cwd = cwd }

  local match = function(_, _, query)
    -- Terminar proceso anterior si existe
    pcall(vim.loop.process_kill, process)

    -- Para query vacío, mostrar items vacíos
    if #query == 0 then
      return MiniPick.set_picker_items({}, set_items_opts)
    end

    -- Obtener el query completo como string
    local full_query = table.concat(query)

    -- Separar por doble espacio (patrón de búsqueda  filtro de archivo)
    local parts = vim.split(full_query, '  ', { plain = true })
    local search_pattern = parts[1]
    local file_pattern = parts[2]

    -- Construir comando de ripgrep
    local command = {
      'rg',
      '--color=never',
      '--no-heading',
      '--with-filename',
      '--line-number',
      '--column',
      '--smart-case',
    }

    -- Añadir patrón de búsqueda
    if search_pattern and search_pattern ~= '' then
      table.insert(command, '-e')
      table.insert(command, search_pattern)
    else
      return MiniPick.set_picker_items({}, set_items_opts)
    end

    -- Añadir filtro de archivo si se proporciona
    if file_pattern and file_pattern ~= '' then
      table.insert(command, '-g')
      -- Usar shortcut si existe, sino usar el patrón directamente
      local pattern = shortcuts[file_pattern] or file_pattern
      table.insert(command, pattern)
    end

    -- Ejecutar ripgrep y procesar resultados
    process = MiniPick.set_picker_items_from_cli(command, {
      postprocess = function(lines)
        local results = {}
        for _, line in ipairs(lines) do
          if line ~= '' then
            local file, lnum, col, text = line:match '([^:]+):(%d+):(%d+):(.*)'
            if file then
              results[#results + 1] = {
                path = file,
                lnum = tonumber(lnum),
                col = tonumber(col),
                text = line,
              }
            end
          end
        end
        return results
      end,
      set_items_opts = set_items_opts,
      spawn_opts = spawn_opts,
    })
  end

  MiniPick.start {
    source = {
      cwd = cwd,
      items = {},
      name = 'Multi Grep (with shortcuts)',
      match = match,
      show = function(buf_id, items_to_show, query)
        MiniPick.default_show(buf_id, items_to_show, query, { show_icons = true })
      end,
      choose = MiniPick.default_choose,
    },
  }
end

--- Global live grep
-- Busca con grep desde donde se abrió Neovim
function M.global_grep()
  local MiniPick = require 'mini.pick'
  MiniPick.builtin.grep_live({}, { source = { cwd = root.global_root() } })
end

--- Git status picker (modified files)
function M.git_status()
  local git_utils = require 'utils.git'
  local repo_path = git_utils.get_git_repo_path()
  if not repo_path then
    vim.notify('Not in a Git repository', vim.log.levels.WARN)
    return
  end

  local MiniExtra = require 'mini.extra'
  MiniExtra.pickers.git_files({ scope = 'modified' }, { source = { cwd = repo_path } })
end

--- Git stash picker with apply/pop/drop actions
function M.git_stash()
  local git_utils = require 'utils.git'
  local repo_path = git_utils.get_git_repo_path()
  if not repo_path then
    vim.notify('Not in a Git repository', vim.log.levels.WARN)
    return
  end

  -- Get stash list using -C flag
  local stash_output = vim.fn.systemlist({ 'git', '-C', repo_path, 'stash', 'list' })
  if vim.v.shell_error ~= 0 or #stash_output == 0 then
    vim.notify('No stashes found', vim.log.levels.INFO)
    return
  end

  -- Create picker
  local MiniPick = require 'mini.pick'

  MiniPick.start {
    source = {
      cwd = repo_path,
      items = stash_output,
      name = 'Git Stash (Enter=apply, Ctrl-p=pop, Ctrl-d=drop)',
      choose = function(selected)
        if not selected then
          return
        end

        -- Extract stash index (e.g., "stash@{0}")
        local stash_index = selected:match '^(stash@{%d+})'
        if not stash_index then
          vim.notify('Invalid stash selected', vim.log.levels.ERROR)
          return
        end

        -- Ask user what to do
        local choice = vim.fn.confirm('What do you want to do with ' .. stash_index .. '?',
          '&Apply\n&Pop\n&Drop\n&Cancel', 4)

        if choice == 1 then
          -- Apply using -C flag
          local result = vim.fn.system({ 'git', '-C', repo_path, 'stash', 'apply', stash_index })
          if vim.v.shell_error == 0 then
            vim.notify('Applied stash: ' .. stash_index, vim.log.levels.INFO)
            vim.cmd 'checktime'
          else
            vim.notify('Failed to apply stash: ' .. result, vim.log.levels.ERROR)
          end
        elseif choice == 2 then
          -- Pop using -C flag
          local result = vim.fn.system({ 'git', '-C', repo_path, 'stash', 'pop', stash_index })
          if vim.v.shell_error == 0 then
            vim.notify('Popped stash: ' .. stash_index, vim.log.levels.INFO)
            vim.cmd 'checktime'
          else
            vim.notify('Failed to pop stash: ' .. result, vim.log.levels.ERROR)
          end
        elseif choice == 3 then
          -- Drop
          local confirm_drop = vim.fn.confirm('Are you sure you want to drop ' .. stash_index .. '?', '&Yes\n&No', 2)
          if confirm_drop == 1 then
            local result = vim.fn.system({ 'git', '-C', repo_path, 'stash', 'drop', stash_index })
            if vim.v.shell_error == 0 then
              vim.notify('Dropped stash: ' .. stash_index, vim.log.levels.INFO)
            else
              vim.notify('Failed to drop stash: ' .. result, vim.log.levels.ERROR)
            end
          end
        end
      end,
    },
  }
end

return M
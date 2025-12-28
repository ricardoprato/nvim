-- Utilidades para mini.pick (reemplazo de telescope)
-- Provee funcionalidad project-aware y custom pickers

local M = {}

-- Get project root (reutiliza utils.root existente)
local function get_project_root()
  local root_utils = require 'utils.root'
  return root_utils.project_root() or vim.fn.getcwd()
end

-- Get global root (donde se abrió Neovim)
local function get_global_root()
  local root_utils = require 'utils.root'
  return root_utils.global_root()
end

--- Execute function in specific directory without permanently changing cwd
--- Saves current directory, changes to target, executes function, restores original
local function with_cwd(dir, fn)
  local original_cwd = vim.fn.getcwd()
  vim.fn.chdir(dir)

  -- Execute function with pcall to ensure cwd is restored even if fn fails
  local success, result = pcall(fn)

  -- Always restore original cwd
  vim.fn.chdir(original_cwd)

  -- Re-raise error if fn failed
  if not success then
    error(result)
  end

  return result
end

--- Project-aware file picker
-- Busca archivos dentro del proyecto Git (o cwd si no hay git)
function M.project_files()
  local MiniPick = require 'mini.pick'
  local root = get_project_root()
  with_cwd(root, function()
    MiniPick.builtin.files()
  end)
end

--- Global file picker
-- Busca archivos desde donde se abrió Neovim
function M.global_files()
  local MiniPick = require 'mini.pick'
  local root = get_global_root()
  with_cwd(root, function()
    MiniPick.builtin.files()
  end)
end

--- Project-aware live grep
-- Busca con grep dentro del proyecto Git (o cwd si no hay git)
function M.project_grep()
  local MiniPick = require 'mini.pick'
  local root = get_project_root()
  with_cwd(root, function()
    MiniPick.builtin.grep_live()
  end)
end

--- Multi-grep (alias para project_grep por ahora)
-- Simplemente usa el grep normal de mini.pick
function M.multi_grep()
  M.project_grep()
end

--- Global live grep
-- Busca con grep desde donde se abrió Neovim
function M.global_grep()
  local MiniPick = require 'mini.pick'
  local root = get_global_root()
  with_cwd(root, function()
    MiniPick.builtin.grep_live()
  end)
end

--- Grep word under cursor (project-aware)
function M.grep_word()
  local word = vim.fn.expand '<cword>'
  if word == '' then
    vim.notify('No word under cursor', vim.log.levels.WARN)
    return
  end

  local MiniPick = require 'mini.pick'
  local root = get_project_root()
  with_cwd(root, function()
    MiniPick.builtin.grep { pattern = word }
  end)
end

--- Search in current buffer
function M.buffer_lines()
  local MiniExtra = require 'mini.extra'
  MiniExtra.pickers.buf_lines { scope = 'current' }
end

--- Search in open buffers (grep)
function M.grep_open_buffers()
  -- Get all open buffer paths
  local buffers = vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) ~= ''
  end, vim.api.nvim_list_bufs())

  if #buffers == 0 then
    vim.notify('No open buffers', vim.log.levels.WARN)
    return
  end

  local MiniPick = require 'mini.pick'
  -- Use grep_live in current directory (buffers are already open)
  MiniPick.builtin.grep_live()
end

--- Search in Neovim config files
function M.config_files()
  local MiniPick = require 'mini.pick'
  local config_path = vim.fn.stdpath 'config'
  with_cwd(config_path, function()
    MiniPick.builtin.files()
  end)
end

--- Git status picker (modified files)
function M.git_status()
  local git_utils = require 'utils.git'
  local repo_path = git_utils.get_git_repo_path()
  if not repo_path then
    vim.notify('Not in a Git repository', vim.log.levels.WARN)
    return
  end

  with_cwd(repo_path, function()
    local MiniExtra = require 'mini.extra'
    MiniExtra.pickers.git_files { scope = 'modified' }
  end)
end

--- Git commits for current buffer
function M.git_buffer_commits()
  local bufpath = vim.api.nvim_buf_get_name(0)
  if bufpath == '' then
    vim.notify('Buffer has no file', vim.log.levels.WARN)
    return
  end

  local MiniExtra = require 'mini.extra'
  MiniExtra.pickers.git_commits { path = bufpath }
end

--- Git commits (project-aware)
function M.git_commits()
  local git_utils = require 'utils.git'
  local repo_path = git_utils.get_git_repo_path()
  if not repo_path then
    vim.notify('Not in a Git repository', vim.log.levels.WARN)
    return
  end

  with_cwd(repo_path, function()
    local MiniExtra = require 'mini.extra'
    MiniExtra.pickers.git_commits()
  end)
end

--- Git branches (project-aware) with checkout functionality
function M.git_branches()
  local git_utils = require 'utils.git'
  local repo_path = git_utils.get_git_repo_path()
  if not repo_path then
    vim.notify('Not in a Git repository', vim.log.levels.WARN)
    return
  end

  with_cwd(repo_path, function()
    -- Get list of branches
    local branches_output = vim.fn.systemlist('git branch --all --sort=-committerdate')
    if vim.v.shell_error ~= 0 then
      vim.notify('Failed to get git branches', vim.log.levels.ERROR)
      return
    end

    -- Parse branches
    local branches = {}
    local current_branch = nil
    for _, line in ipairs(branches_output) do
      local is_current = line:match '^%*'
      local branch = line:gsub('^%*?%s*', ''):gsub('^remotes/', ''):gsub(' %-> .*', '')

      if branch ~= '' and not branch:match('HEAD') then
        table.insert(branches, branch)
        if is_current then
          current_branch = branch
        end
      end
    end

    -- Create picker
    local MiniPick = require 'mini.pick'
    local items = vim.tbl_map(function(branch)
      local prefix = (branch == current_branch) and '* ' or '  '
      return prefix .. branch
    end, branches)

    MiniPick.start {
      source = {
        items = items,
        name = 'Git Branches',
        choose = function(selected)
          if not selected then
            return
          end

          -- Extract branch name (remove prefix)
          local branch = selected:gsub('^[* ] ', '')

          -- Checkout branch
          local result = vim.fn.system('git checkout ' .. vim.fn.shellescape(branch))
          if vim.v.shell_error == 0 then
            vim.notify('Switched to branch: ' .. branch, vim.log.levels.INFO)
            -- Reload buffers to reflect changes
            vim.cmd('checktime')
          else
            vim.notify('Failed to checkout branch: ' .. result, vim.log.levels.ERROR)
          end
        end,
      },
    }
  end)
end

--- Git hunks (modified hunks in current buffer)
function M.git_hunks()
  local git_utils = require 'utils.git'
  local repo_path = git_utils.get_git_repo_path()
  if not repo_path then
    vim.notify('Not in a Git repository', vim.log.levels.WARN)
    return
  end

  with_cwd(repo_path, function()
    local MiniExtra = require 'mini.extra'
    MiniExtra.pickers.git_hunks()
  end)
end

--- Git stash picker with apply/pop/drop actions
function M.git_stash()
  local git_utils = require 'utils.git'
  local repo_path = git_utils.get_git_repo_path()
  if not repo_path then
    vim.notify('Not in a Git repository', vim.log.levels.WARN)
    return
  end

  with_cwd(repo_path, function()
    -- Get stash list
    local stash_output = vim.fn.systemlist('git stash list')
    if vim.v.shell_error ~= 0 or #stash_output == 0 then
      vim.notify('No stashes found', vim.log.levels.INFO)
      return
    end

    -- Create picker
    local MiniPick = require 'mini.pick'

    MiniPick.start {
      source = {
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
          local choice = vim.fn.confirm('What do you want to do with ' .. stash_index .. '?', '&Apply\n&Pop\n&Drop\n&Cancel', 4)

          if choice == 1 then
            -- Apply
            local result = vim.fn.system('git stash apply ' .. stash_index)
            if vim.v.shell_error == 0 then
              vim.notify('Applied stash: ' .. stash_index, vim.log.levels.INFO)
              vim.cmd('checktime')
            else
              vim.notify('Failed to apply stash: ' .. result, vim.log.levels.ERROR)
            end
          elseif choice == 2 then
            -- Pop
            local result = vim.fn.system('git stash pop ' .. stash_index)
            if vim.v.shell_error == 0 then
              vim.notify('Popped stash: ' .. stash_index, vim.log.levels.INFO)
              vim.cmd('checktime')
            else
              vim.notify('Failed to pop stash: ' .. result, vim.log.levels.ERROR)
            end
          elseif choice == 3 then
            -- Drop
            local confirm_drop = vim.fn.confirm('Are you sure you want to drop ' .. stash_index .. '?', '&Yes\n&No', 2)
            if confirm_drop == 1 then
              local result = vim.fn.system('git stash drop ' .. stash_index)
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
  end)
end

-- ============================================================================
-- Odoo Scoped Grep Functions
-- ============================================================================

--- Detect Odoo root directory (e.g., 18.0/, 17.0/, etc.)
--- Walks up directory tree looking for odoo/ and enterprise/ subdirectories
local function detect_odoo_root()
  -- Start from current buffer directory
  local start_path = vim.fn.expand('%:p:h')
  if start_path == '' then
    start_path = vim.fn.getcwd()
  end

  -- Walk up directory tree looking for Odoo markers
  local current = start_path
  while current and current ~= '/' do
    -- Check for odoo/ and enterprise/ subdirectories
    local odoo_path = current .. '/odoo'
    local enterprise_path = current .. '/enterprise'

    if vim.fn.isdirectory(odoo_path) == 1 and vim.fn.isdirectory(enterprise_path) == 1 then
      -- Additional validation: check for odoo-bin or .venv
      if vim.fn.filereadable(odoo_path .. '/odoo-bin') == 1 or vim.fn.isdirectory(current .. '/.venv') == 1 then
        return current
      end
    end

    -- Move up one directory
    current = vim.fn.fnamemodify(current, ':h')
  end

  -- Fallback: check global_root()
  local global_root = get_global_root()
  if global_root then
    local odoo_in_global = global_root .. '/odoo'
    if vim.fn.isdirectory(odoo_in_global) == 1 then
      return global_root
    end
  end

  return nil
end

--- Detect current client from buffer path
--- Returns client name and client path if detected
local function detect_current_client(odoo_root, bufpath)
  if not odoo_root or not bufpath or bufpath == '' then
    return nil, nil
  end

  -- Expected pattern: .../18.0/extra-addons/cliente1/...
  local extra_addons = odoo_root .. '/extra-addons/'

  -- Check if buffer is inside extra-addons
  if bufpath:sub(1, #extra_addons) == extra_addons then
    -- Extract client directory name (first path component after extra-addons/)
    local relative = bufpath:sub(#extra_addons + 1)
    local client = relative:match('^([^/]+)')

    -- Validate it's a directory
    if client then
      local client_path = extra_addons .. client
      if vim.fn.isdirectory(client_path) == 1 then
        return client, client_path
      end
    end
  end

  return nil, nil
end

--- Build scope items for picker
--- Returns table with {text, scope_name, search_path} for each available scope
local function build_scope_items(odoo_root, current_client_name, current_client_path)
  local items = {}

  -- Scope 1: Todo (All) - search entire Odoo root
  local root_dirname = vim.fn.fnamemodify(odoo_root, ':t')
  table.insert(items, {
    text = string.format('Todo (All) - Search entire %s/', root_dirname),
    scope_name = 'Todo',
    search_path = odoo_root,
  })

  -- Scope 2: Odoo Core
  local odoo_core_path = odoo_root .. '/odoo'
  if vim.fn.isdirectory(odoo_core_path) == 1 then
    table.insert(items, {
      text = 'Odoo Core - odoo/',
      scope_name = 'Odoo Core',
      search_path = odoo_core_path,
    })
  end

  -- Scope 3: Enterprise
  local enterprise_path = odoo_root .. '/enterprise'
  if vim.fn.isdirectory(enterprise_path) == 1 then
    table.insert(items, {
      text = 'Enterprise - enterprise/',
      scope_name = 'Enterprise',
      search_path = enterprise_path,
    })
  end

  -- Scope 4: Cliente Actual (if detected)
  if current_client_name and current_client_path then
    table.insert(items, {
      text = string.format('Cliente Actual - %s/', current_client_name),
      scope_name = 'Cliente: ' .. current_client_name,
      search_path = current_client_path,
    })
  end

  -- Scope 5: Extra Addons (All)
  local extra_addons_path = odoo_root .. '/extra-addons'
  if vim.fn.isdirectory(extra_addons_path) == 1 then
    table.insert(items, {
      text = 'Extra Addons (All) - extra-addons/',
      scope_name = 'Extra Addons',
      search_path = extra_addons_path,
    })
  end

  return items
end

--- Execute scoped grep in specific path
local function execute_scoped_grep(scope_name, search_path)
  local MiniPick = require 'mini.pick'

  with_cwd(search_path, function()
    MiniPick.builtin.grep_live()
  end)
end

--- Odoo scoped grep selector
--- Shows picker with available scopes, then executes grep in selected scope
function M.odoo_scoped_grep()
  -- 1. Detect Odoo root
  local odoo_root = detect_odoo_root()
  if not odoo_root then
    vim.notify('Not in an Odoo project', vim.log.levels.WARN)
    return
  end

  -- 2. Detect current client
  local bufpath = vim.api.nvim_buf_get_name(0)
  local client_name, client_path = detect_current_client(odoo_root, bufpath)

  -- 3. Build scope items
  local scope_items = build_scope_items(odoo_root, client_name, client_path)

  if #scope_items == 0 then
    vim.notify('No valid scopes found', vim.log.levels.WARN)
    return
  end

  -- 4. Create scope selector picker
  local MiniPick = require 'mini.pick'

  MiniPick.start({
    source = {
      items = vim.tbl_map(function(item) return item.text end, scope_items),
      name = 'Odoo Scoped Grep',
      choose = function(selected_text)
        if not selected_text then
          return
        end

        -- Find selected scope item
        for _, item in ipairs(scope_items) do
          if item.text == selected_text then
            -- Execute scoped grep
            execute_scoped_grep(item.scope_name, item.search_path)
            break
          end
        end
      end,
    },
  })
end

return M

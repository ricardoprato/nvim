local M = {}
local root = require('utils.root')

--- Discover git repositories under global root (up to depth 3)
local function get_repos()
  local global = root.global_root()

  local out = vim.system(
    { 'find', global, '-maxdepth', '5', '-name', '.git', '-type', 'd' },
    { text = true, stderr = false }
  ):wait()
  if out.code ~= 0 then return {} end

  local output = out.stdout

  local repos = {}
  local escaped_root = vim.pesc(global) .. '/'
  for git_dir in output:gmatch('[^\r\n]+') do
    local repo_path = vim.fn.fnamemodify(git_dir, ':h')
    local relative = repo_path:gsub('^' .. escaped_root, '')
    repos[#repos + 1] = { path = repo_path, relative = relative }
  end

  table.sort(repos, function(a, b) return a.relative < b.relative end)
  return repos
end

--- Format repo item with branch and sync info for display
local function format_repo_item(repo)
  local git = require('utils.git')
  local branch = git.get_current_branch(repo.path) or 'unknown'

  local status = git.get_ahead_behind(repo.path)
  local sync = ''
  if status.ahead > 0 then sync = sync .. ' ↑' .. status.ahead end
  if status.behind > 0 then sync = sync .. ' ↓' .. status.behind end

  return {
    text = string.format('[%s] %s%s', repo.relative, branch, sync),
    path = repo.path,
    relative = repo.relative,
    branch = branch,
  }
end

--- Global file picker
-- Busca archivos desde donde se abrió Neovim
function M.global_files()
  local MiniPick = require 'mini.pick'
  MiniPick.builtin.files({ tool = 'fd' }, { source = { cwd = root.global_root() } })
end

--- Global live grep
-- Busca con grep desde donde se abrió Neovim
function M.global_grep()
  local MiniPick = require 'mini.pick'
  MiniPick.builtin.grep_live({}, { source = { cwd = root.global_root() } })
end

--- Git stash picker with apply/pop/drop actions
function M.git_stash()
  local repo_path = root.git_root()
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

--- Git status picker (all changed files: modified, staged, untracked, deleted)
function M.git_branch_files()
  local repo_path = root.git_root() or root.git_root(vim.fn.getcwd())
  if not repo_path then
    vim.notify('Not in a Git repository', vim.log.levels.WARN)
    return
  end

  local output = vim.fn.systemlist({ 'git', '-C', repo_path, 'status', '--porcelain' })
  if vim.v.shell_error ~= 0 or #output == 0 then
    vim.notify('Working tree clean', vim.log.levels.INFO)
    return
  end

  -- git status --porcelain format: XY filename
  -- X = index (staged), Y = worktree (unstaged)
  local status_labels = {
    ['M'] = 'Modified',
    ['A'] = 'Added',
    ['D'] = 'Deleted',
    ['R'] = 'Renamed',
    ['C'] = 'Copied',
    ['?'] = 'Untracked',
    ['U'] = 'Conflict',
  }

  local items = {}
  for _, line in ipairs(output) do
    local xy = line:sub(1, 2)
    local filepath = line:sub(4)
    local index_status = xy:sub(1, 1)
    local worktree_status = xy:sub(2, 2)

    -- Handle renamed: "R  old -> new"
    local display_path = filepath
    if index_status == 'R' or worktree_status == 'R' then
      local _, new_path = filepath:match('^(.+) %-> (.+)$')
      if new_path then display_path = new_path end
    end

    -- Skip directories
    local full_path = repo_path .. '/' .. display_path
    if vim.fn.isdirectory(full_path) == 1 then
      goto continue
    end

    -- Build label showing stage state
    local parts = {}
    if index_status ~= ' ' and index_status ~= '?' then
      table.insert(parts, 'Staged:' .. (status_labels[index_status] or index_status))
    end
    if worktree_status ~= ' ' and worktree_status ~= '?' then
      table.insert(parts, status_labels[worktree_status] or worktree_status)
    end
    if index_status == '?' then
      table.insert(parts, 'Untracked')
    end
    local label = table.concat(parts, ' | ')

    items[#items + 1] = {
      text = string.format('[%s] %s', label, display_path),
      path = repo_path .. '/' .. display_path,
      index = index_status,
      worktree = worktree_status,
    }
    ::continue::
  end

  local MiniPick = require 'mini.pick'
  MiniPick.start({
    source = {
      cwd = repo_path,
      items = items,
      name = 'Git Status',
      show = function(buf_id, items_to_show, query)
        MiniPick.default_show(buf_id, items_to_show, query, { show_icons = true })
      end,
      preview = function(buf_id, item)
        local diff_cmd
        if item.index ~= ' ' and item.index ~= '?' then
          -- Show staged diff
          diff_cmd = { 'git', '-C', repo_path, 'diff', '--cached', '--', item.path }
        elseif item.worktree == '?' then
          -- Untracked: show file contents
          local ok, lines = pcall(vim.fn.readfile, item.path, '', 200)
          if not ok or not lines then
            vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, { '(Cannot read file)' })
            return
          end
          -- Sanitize lines that contain embedded newlines (binary files)
          for i, line in ipairs(lines) do
            if line:find('\n') then lines[i] = line:gsub('\n', '') end
          end
          vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
          local ft = vim.filetype.match({ filename = item.path }) or ''
          vim.bo[buf_id].filetype = ft
          return
        else
          -- Show unstaged diff
          diff_cmd = { 'git', '-C', repo_path, 'diff', '--', item.path }
        end
        local diff_output = vim.fn.systemlist(diff_cmd)
        for i, line in ipairs(diff_output) do
          if line:find('\n') then diff_output[i] = line:gsub('\n', '') end
        end
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, diff_output)
        vim.bo[buf_id].filetype = 'diff'
      end,
      choose = function(item)
        if not item then return end
        if item.worktree == 'D' and item.index == ' ' then
          vim.notify('File was deleted: ' .. item.path, vim.log.levels.INFO)
          return
        end
        MiniPick.default_choose(item)
      end,
    },
  })
end

--- Repo picker - select from available git repositories under global root
-- Enter=files, C-o=explorer, C-g=lazygit, C-b=branches, C-s=status
function M.repo_picker()
  local repos = get_repos()
  if #repos == 0 then
    vim.notify('No git repositories found under ' .. root.global_root(), vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, repo in ipairs(repos) do
    items[#items + 1] = format_repo_item(repo)
  end

  local MiniPick = require 'mini.pick'

  --- Helper to get current item and close picker
  local function pick_item_and_stop()
    local matches = MiniPick.get_picker_matches()
    if not matches or not matches.current then return nil end
    local item = matches.current
    MiniPick.stop()
    return item
  end

  MiniPick.start({
    source = {
      items = items,
      name = 'Repos (CR=files C-o=explore C-g=lazygit C-b=branch C-s=status)',

      show = function(buf_id, items_to_show, query)
        MiniPick.default_show(buf_id, items_to_show, query, { show_icons = true })
      end,

      preview = function(buf_id, item)
        if not item then return end
        local status_output = vim.fn.systemlist({ 'git', '-C', item.path, 'status', '--short' })

        local lines = {
          'Repository: ' .. item.relative,
          'Path:       ' .. item.path,
          'Branch:     ' .. item.branch,
          '',
          'Status:',
          '-------',
        }

        if vim.v.shell_error == 0 and #status_output > 0 then
          vim.list_extend(lines, status_output)
        else
          lines[#lines + 1] = '(clean)'
        end

        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        vim.bo[buf_id].filetype = 'git'
      end,

      choose = function(item)
        if not item then return end
        MiniPick.builtin.files({}, { source = { cwd = item.path } })
      end,
    },

    mappings = {
      open_explorer = {
        char = '<C-o>',
        func = function()
          local item = pick_item_and_stop()
          if not item then return end
          vim.schedule(function() MiniFiles.open(item.path) end)
        end,
      },

      open_lazygit = {
        char = '<C-g>',
        func = function()
          local item = pick_item_and_stop()
          if not item then return end
          vim.schedule(function()
            require('utils.float-term').lazygit(item.path)
          end)
        end,
      },

      show_branches = {
        char = '<C-b>',
        func = function()
          local item = pick_item_and_stop()
          if not item then return end
          vim.schedule(function()
            local git = require('utils.git')
            local branches = git.get_recent_branches(item.path)
            MiniPick.start({
              source = {
                cwd = item.path,
                items = branches,
                name = 'Branches [' .. item.relative .. ']',
                choose = function(branch)
                  if branch then git.switch_branch(branch, item.path) end
                end,
              },
            })
          end)
        end,
      },

      show_status = {
        char = '<C-s>',
        func = function()
          local item = pick_item_and_stop()
          if not item then return end
          vim.schedule(function()
            local output = vim.fn.systemlist({ 'git', '-C', item.path, 'status', '--porcelain' })
            if vim.v.shell_error ~= 0 or #output == 0 then
              vim.notify('[' .. item.relative .. '] Working tree clean', vim.log.levels.INFO)
              return
            end

            local status_labels = {
              ['M'] = 'Modified', ['A'] = 'Added', ['D'] = 'Deleted',
              ['R'] = 'Renamed', ['?'] = 'Untracked', ['U'] = 'Conflict',
            }

            local status_items = {}
            for _, line in ipairs(output) do
              local xy = line:sub(1, 2)
              local filepath = line:sub(4)
              local idx, wt = xy:sub(1, 1), xy:sub(2, 2)

              local parts = {}
              if idx ~= ' ' and idx ~= '?' then
                parts[#parts + 1] = 'Staged:' .. (status_labels[idx] or idx)
              end
              if wt ~= ' ' and wt ~= '?' then
                parts[#parts + 1] = status_labels[wt] or wt
              end
              if idx == '?' then
                parts[#parts + 1] = 'Untracked'
              end

              status_items[#status_items + 1] = {
                text = string.format('[%s] %s', table.concat(parts, ' | '), filepath),
                path = filepath,
              }
            end

            MiniPick.start({
              source = {
                cwd = item.path,
                items = status_items,
                name = 'Status [' .. item.relative .. ']',
                show = function(buf_id, items_to_show, query)
                  MiniPick.default_show(buf_id, items_to_show, query, { show_icons = true })
                end,
                choose = function(selected)
                  if not selected then return end
                  vim.cmd('edit ' .. vim.fn.fnameescape(item.path .. '/' .. selected.path))
                end,
              },
            })
          end)
        end,
      },
    },
  })
end

return M


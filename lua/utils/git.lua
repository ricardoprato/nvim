local M = {}
local root = require('utils.root')

-- Alias para compatibilidad con código existente
M.get_git_repo_path = root.git_root
M.is_git_repo = root.is_git_repo
M.git_root = root.git_root
M.project_root = root.project_root

-- Get recent branches (sorted by last commit date) for repo of current buffer
function M.get_recent_branches(repo_path)
  repo_path = repo_path or M.get_git_repo_path()
  if not repo_path then
    return {}
  end

  local cmd = string.format(
    "git -C %s for-each-ref --sort=-committerdate refs/heads/ --format='%%(refname:short)'",
    vim.fn.shellescape(repo_path)
  )
  local handle = io.popen(cmd)
  if not handle then
    return {}
  end

  local result = handle:read('*a')
  handle:close()

  local branches = {}
  for branch in result:gmatch('[^\r\n]+') do
    table.insert(branches, branch)
  end

  return branches
end

-- Get current branch name for repo of current buffer
function M.get_current_branch(repo_path)
  repo_path = repo_path or M.get_git_repo_path()
  if not repo_path then
    return nil
  end

  local cmd = string.format('git -C %s branch --show-current', vim.fn.shellescape(repo_path))
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end

  local branch = handle:read('*a'):gsub('\n', '')
  handle:close()

  return branch ~= '' and branch or nil
end

-- Switch to branch in repo of current buffer
function M.switch_branch(branch, repo_path)
  repo_path = repo_path or M.get_git_repo_path()
  if not repo_path then
    vim.notify('Not in a git repository', vim.log.levels.WARN)
    return
  end

  local current = M.get_current_branch(repo_path)
  if current == branch then
    vim.notify('Already on branch: ' .. branch, vim.log.levels.INFO)
    return
  end

  local repo_name = vim.fn.fnamemodify(repo_path, ':t')
  vim.cmd('Git -C ' .. vim.fn.fnameescape(repo_path) .. ' checkout ' .. branch)
  vim.notify('[' .. repo_name .. '] Switched to branch: ' .. branch, vim.log.levels.INFO)
end

-- Get repo name (for display purposes)
function M.get_repo_name(repo_path)
  repo_path = repo_path or M.get_git_repo_path()
  if not repo_path then
    return nil
  end
  return vim.fn.fnamemodify(repo_path, ':t')
end

return M

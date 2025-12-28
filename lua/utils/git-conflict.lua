local M = {}

-- Conflict markers
local conflict_markers = {
  ours = '^<<<<<<< ',
  theirs = '^>>>>>>> ',
  separator = '^=======',
}

-- Jump to next conflict marker
function M.next_conflict()
  local pattern = '\\v(' .. table.concat({
    conflict_markers.ours,
    conflict_markers.theirs,
    conflict_markers.separator,
  }, '|') .. ')'

  vim.fn.search(pattern, 'W')
end

-- Jump to previous conflict marker
function M.prev_conflict()
  local pattern = '\\v(' .. table.concat({
    conflict_markers.ours,
    conflict_markers.theirs,
    conflict_markers.separator,
  }, '|') .. ')'

  vim.fn.search(pattern, 'bW')
end

-- Choose ours (keep current changes, discard incoming)
function M.choose_ours()
  local start_line = vim.fn.search('^<<<<<<< ', 'bcnW')
  local sep_line = vim.fn.search('^=======', 'nW')
  local end_line = vim.fn.search('^>>>>>>> ', 'nW')

  if start_line > 0 and sep_line > 0 and end_line > 0 then
    -- Delete theirs section and markers
    vim.cmd(string.format('%d,%dd', sep_line, end_line))
    vim.cmd(string.format('%dd', start_line))
    vim.notify('Conflict resolved: kept OURS', vim.log.levels.INFO)
  else
    vim.notify('No conflict found at cursor', vim.log.levels.WARN)
  end
end

-- Choose theirs (discard current changes, keep incoming)
function M.choose_theirs()
  local start_line = vim.fn.search('^<<<<<<< ', 'bcnW')
  local sep_line = vim.fn.search('^=======', 'nW')
  local end_line = vim.fn.search('^>>>>>>> ', 'nW')

  if start_line > 0 and sep_line > 0 and end_line > 0 then
    -- Delete ours section and markers
    vim.cmd(string.format('%d,%dd', start_line, sep_line))
    vim.cmd(string.format('%dd', end_line - (sep_line - start_line + 1)))
    vim.notify('Conflict resolved: kept THEIRS', vim.log.levels.INFO)
  else
    vim.notify('No conflict found at cursor', vim.log.levels.WARN)
  end
end

-- Choose both (keep both changes)
function M.choose_both()
  local start_line = vim.fn.search('^<<<<<<< ', 'bcnW')
  local sep_line = vim.fn.search('^=======', 'nW')
  local end_line = vim.fn.search('^>>>>>>> ', 'nW')

  if start_line > 0 and sep_line > 0 and end_line > 0 then
    -- Just delete markers
    vim.cmd(string.format('%dd', end_line))
    vim.cmd(string.format('%dd', sep_line))
    vim.cmd(string.format('%dd', start_line))
    vim.notify('Conflict resolved: kept BOTH', vim.log.levels.INFO)
  else
    vim.notify('No conflict found at cursor', vim.log.levels.WARN)
  end
end

-- List all conflicts in current buffer
function M.list_conflicts()
  local conflicts = {}
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for i, line in ipairs(lines) do
    if line:match('^<<<<<<< ') then
      table.insert(conflicts, { lnum = i, text = line })
    end
  end

  if #conflicts == 0 then
    vim.notify('No conflicts found in buffer', vim.log.levels.INFO)
  else
    vim.fn.setqflist({}, 'r', {
      title = 'Git Conflicts',
      items = conflicts,
    })
    vim.cmd('copen')
    vim.notify(string.format('Found %d conflicts', #conflicts), vim.log.levels.INFO)
  end
end

return M

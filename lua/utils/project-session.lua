-- Project-aware session management
-- Automatically derives session names from project paths and handles
-- save/restore when switching between projects.
local M = {}

local function sessions_available()
  return rawget(_G, 'MiniSessions') ~= nil
end

--- Get session directory from MiniSessions config or fallback
local function session_dir()
  if sessions_available() and MiniSessions.config then
    return MiniSessions.config.directory
  end
  return vim.fn.stdpath('data') .. '/sessions'
end

--- Derive a session name from a project path
--- ~/dev/myproject -> dev--myproject
--- ~/odoo/17.0 -> odoo--17.0
function M.session_name(project_path)
  project_path = project_path or vim.fn.getcwd()
  local home = vim.fn.expand('~')
  local relative = project_path:gsub('^' .. vim.pesc(home) .. '/', '')
  return relative:gsub('/', '--')
end

--- Save current session with project-derived name
function M.save()
  if not sessions_available() then return end
  local name = M.session_name()
  if name == '' then return end
  MiniSessions.write(name)
end

--- Load session for a given project path, if it exists
--- Returns true if a session was loaded
function M.load(project_path)
  if not sessions_available() then return false end
  local name = M.session_name(project_path)
  local session_file = session_dir() .. '/' .. name

  if vim.uv.fs_stat(session_file) then
    MiniSessions.read(name)
    return true
  end
  return false
end

--- Switch to a project: save current session, change cwd, load target session if it exists
function M.switch_to(project_path)
  -- Save current session if one is active
  if vim.v.this_session ~= '' then
    pcall(M.save)
  end

  -- Change directory
  vim.cmd('cd ' .. vim.fn.fnameescape(project_path))

  -- Load the project's session if one exists (silently skip otherwise)
  M.load(project_path)
end

return M

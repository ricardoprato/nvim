local M = {}

-- Usar el directorio inicial capturado en init.lua (antes de cualquier plugin)
-- Fallback al cwd actual si por alguna razón no está definido
local initial_cwd = _G.Config and _G.Config.initial_cwd or vim.fn.getcwd()

-- Ruta del buffer actual
function M.bufpath()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  if path == '' then
    return vim.uv.cwd()
  end
  return vim.fs.dirname(vim.fn.fnamemodify(path, ':p'))
end

-- Comprueba si el buffer está dentro de un repo Git
function M.is_git_repo(path)
  path = path or M.bufpath()
  vim.fn.system { 'git', '-C', path, 'rev-parse', '--is-inside-work-tree' }
  return vim.v.shell_error == 0
end

-- Raíz Git del buffer
function M.git_root(path)
  path = path or M.bufpath()
  local root = vim.fn.system { 'git', '-C', path, 'rev-parse', '--show-toplevel' }
  if vim.v.shell_error == 0 then
    return vim.trim(root)
  end
  return nil
end

-- Directorio desde el cual se abrió Neovim
function M.global_root()
  return initial_cwd
end

-- Raíz del proyecto actual (git o cwd)
function M.project_root()
  return M.git_root() or M.global_root()
end

return M

local M = {}

-- Usar el directorio inicial capturado en init.lua (antes de cualquier plugin)
-- Fallback al cwd actual si por alguna razón no está definido
local initial_cwd = _G.Config and _G.Config.initial_cwd or vim.fn.getcwd()

-- io.popen() usa pclose() a nivel C, que bloquea sin bombear el event loop de Neovim.
-- Esto evita re-entrada en el handler de LSP RPC que causa "response id must be a number".
-- POSIX shell escape: envuelve en comillas simples, escapa comillas simples internas
local function shell_escape(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function git_cmd(path, ...)
	local parts = { "git", "-C", shell_escape(path) }
	for i = 1, select("#", ...) do
		parts[#parts + 1] = select(i, ...)
	end
	parts[#parts + 1] = "2>/dev/null"
	local cmd = table.concat(parts, " ")
	local handle = io.popen(cmd)
	if not handle then
		return nil
	end
	local output = handle:read("*a")
	handle:close()
	return output
end

-- Ruta del buffer actual
function M.bufpath()
	local buf = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(buf)
	if path == "" then
		return vim.uv.cwd()
	end
	return vim.fs.dirname(vim.fn.fnamemodify(path, ":p"))
end

-- Raíz Git del buffer
function M.git_root(path)
	path = path or M.bufpath()
	local out = git_cmd(path, "rev-parse", "--show-toplevel")
	if out and out ~= "" then
		return vim.trim(out)
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

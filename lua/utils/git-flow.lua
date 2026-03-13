local M = {}
local root = require("utils.root")

-- Cache for git-flow commands (similar to mini.git)
local _cache = {
	git_flow_commands = nil,
	git_flow_subcommands = {},
}

-- Get all available git-flow commands
-- Returns a table like: { 'init', 'feature', 'release', 'hotfix', 'bugfix', 'support', ... }
M.get_commands = function()
	if _cache.git_flow_commands then
		return _cache.git_flow_commands
	end

	local out = vim.system({ "git", "flow", "help" }, { text = true, stderr = "stdout" }):wait()
	if out.code ~= 0 then
		return {}
	end

	local output = out.stdout

	local commands = {}
	-- Parse lines that start with "   " followed by a command name
	for line in output:gmatch("[^\r\n]+") do
		local cmd = line:match("^%s+([%w_-]+)%s+")
		if cmd and cmd ~= "or:" then
			table.insert(commands, cmd)
		end
	end

	_cache.git_flow_commands = commands
	return commands
end

-- Get all available subcommands for a specific git-flow command
-- Example: M.get_subcommands('feature') returns { 'start', 'finish', 'publish', ... }
M.get_subcommands = function(command)
	if _cache.git_flow_subcommands[command] then
		return _cache.git_flow_subcommands[command]
	end

	local out = vim.system({ "git", "flow", command, "help" }, { text = true, stderr = "stdout" }):wait()
	if out.code ~= 0 then
		return {}
	end

	local output = out.stdout

	local subcommands = {}
	-- Parse lines like "   or: git flow feature start"
	local pattern = "%s+or:%s+git%s+flow%s+" .. command .. "%s+([%w_-]+)"
	for line in output:gmatch("[^\r\n]+") do
		local subcmd = line:match(pattern)
		if subcmd then
			table.insert(subcommands, subcmd)
		end
	end

	_cache.git_flow_subcommands[command] = subcommands
	return subcommands
end

-- Get all available commands with their subcommands
-- Returns a table like: { feature = { 'start', 'finish', ... }, release = { ... }, ... }
M.get_all_commands = function()
	local all_commands = {}
	local main_commands = M.get_commands()

	for _, cmd in ipairs(main_commands) do
		-- Skip commands that don't have subcommands (like 'init', 'version', 'config')
		if cmd ~= "init" and cmd ~= "version" and cmd ~= "config" and cmd ~= "log" then
			all_commands[cmd] = M.get_subcommands(cmd)
		end
	end

	return all_commands
end

-- Execute git flow command and show output
local function exec(subcmd, args, opts)
	opts = opts or {}

	-- Check if git-flow is available
	if vim.fn.executable("git") == 0 then
		vim.notify("git executable not found", vim.log.levels.ERROR)
		return
	end

	-- Get repository root
	local repo_path = root.git_root()
	if not repo_path then
		vim.notify("Not in a git repository", vim.log.levels.WARN)
		return
	end

	-- Build command
	local cmd = { "git", "flow", subcmd }
	vim.list_extend(cmd, args)

	-- Execute command in terminal buffer (similar to :Git from mini.git)
	local cmd_str = table.concat(cmd, " ")
	vim.cmd("tab term " .. cmd_str)
end

-- Check if git-flow is initialized in the current repo
M.is_initialized = function(repo_path)
	repo_path = repo_path or root.git_root()
	if not repo_path then
		return false
	end

	local out = vim.system(
		{ "git", "-C", repo_path, "config", "--get", "gitflow.branch.master" },
		{ text = true, stderr = false }
	):wait()
	return out.code == 0
end

-- Auto-init git-flow with defaults or interactively
M.auto_init = function(repo_path)
	repo_path = repo_path or root.git_root()
	if not repo_path then
		vim.notify("Not in a git repository", vim.log.levels.WARN)
		return
	end

	if M.is_initialized(repo_path) then
		vim.notify("Git-flow already initialized", vim.log.levels.INFO)
		return
	end

	local choice = vim.fn.confirm("Initialize git-flow?", "&Defaults\n&Interactive\n&Cancel", 3)

	if choice == 1 then
		local result = vim.system({ "git", "-C", repo_path, "flow", "init", "-d" }, { text = true, stderr = "stdout" })
			:wait()
		if result.code == 0 then
			vim.notify("Git-flow initialized with defaults", vim.log.levels.INFO)
		else
			vim.notify("Git-flow init failed: " .. result.stdout, vim.log.levels.ERROR)
		end
	elseif choice == 2 then
		M.init()
	end
end

-- Git Flow Init (interactive, opens terminal)
M.init = function()
	local cmd = { "git", "flow", "init" }
	vim.cmd("tab term " .. table.concat(cmd, " "))
end

-- Command completion function
M.complete = function(arg_lead, cmd_line, cursor_pos)
	local args = vim.split(cmd_line, "%s+")
	local n_args = #args

	-- Remove 'GitFlow' from args
	if args[1] == "GitFlow" then
		table.remove(args, 1)
		n_args = n_args - 1
	end

	-- First argument: complete main commands
	if n_args == 1 then
		local commands = M.get_commands()
		if arg_lead ~= "" then
			return vim.tbl_filter(function(cmd)
				return vim.startswith(cmd, arg_lead)
			end, commands)
		end
		return commands
	end

	-- Second argument: complete subcommands
	if n_args == 2 then
		local main_cmd = args[1]
		local subcommands = M.get_subcommands(main_cmd)
		if arg_lead ~= "" then
			return vim.tbl_filter(function(subcmd)
				return vim.startswith(subcmd, arg_lead)
			end, subcommands)
		end
		return subcommands
	end

	-- Third+ argument: no completion (it's the name/version)
	return {}
end

-- Execute GitFlow command from user command
M.command = function(opts)
	local args = opts.fargs

	if #args == 0 then
		vim.notify("Usage: GitFlow <command> [subcommand] [name]", vim.log.levels.INFO)
		return
	end

	-- Handle special commands without subcommands
	if args[1] == "init" then
		M.init()
		return
	end

	if args[1] == "version" then
		exec("version", {})
		return
	end

	if args[1] == "config" then
		exec("config", vim.list_slice(args, 2))
		return
	end

	-- Regular flow commands (feature, release, hotfix, bugfix)
	if #args < 2 then
		vim.notify("Usage: GitFlow " .. args[1] .. " <subcommand> [name]", vim.log.levels.WARN)
		return
	end

	local main_cmd = args[1]
	local sub_cmd = args[2]
	local name = args[3]

	-- Commands that don't need a name (like 'list')
	local no_name_cmds = { "list", "diff" }
	if vim.tbl_contains(no_name_cmds, sub_cmd) then
		exec(main_cmd, { sub_cmd })
		return
	end

	-- Commands that need a name
	if not name then
		-- Prompt for name if not provided
		local prompt = main_cmd:sub(1, 1):upper() .. main_cmd:sub(2) .. " name: "
		if main_cmd == "release" then
			prompt = "Release version: "
		end
		name = vim.fn.input(prompt)
		if name == "" then
			return
		end
	end

	exec(main_cmd, { sub_cmd, name })
end

return M

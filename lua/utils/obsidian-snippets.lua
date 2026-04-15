local M = {}

--- Extract the first code block from a list of lines
---@param lines string[]
---@return string[]
local function extract_code_block(lines)
	local in_block = false
	local code = {}
	for _, line in ipairs(lines) do
		if in_block then
			if line:match("^```") then break end
			table.insert(code, line)
		elseif line:match("^```") then
			in_block = true
		end
	end
	return code
end

--- Pick a snippet and yank its code block to clipboard
function M.find_and_yank()
	local snippets_dir = vim.fn.expand("~/obsidian/snippets")
	Snacks.picker.pick("files", {
		dirs = { snippets_dir },
		title = "Snippets — yank code block",
		confirm = function(picker, item)
			picker:close()
			if not item or not item.file then return end
			local lines = vim.fn.readfile(item.file)
			local code = extract_code_block(lines)
			if #code > 0 then
				vim.fn.setreg("+", table.concat(code, "\n"))
				Snacks.notify("Snippet copiado (" .. #code .. " lineas)")
			else
				Snacks.notify("No se encontro code block", { level = "warn" })
			end
		end,
		preview = "file",
	})
end

--- Grep inside snippets folder
function M.search()
	Snacks.picker.grep({
		dirs = { vim.fn.expand("~/obsidian/snippets") },
		title = "Buscar en snippets",
	})
end

return M

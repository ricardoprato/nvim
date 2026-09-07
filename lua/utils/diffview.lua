-- ┌────────────────────────────┐
-- │ Diffview view lifecycle    │
-- └────────────────────────────┘
--
-- Every Diffview entry point is a toggle: if a view already owns the current
-- tab, the key closes it instead of stacking another one. That check lived in
-- three places (the <leader>gd and <leader>gv keymaps plus utils.git-base.open);
-- it lives here now.
--
-- Base-branch resolution is a separate concern, see utils.git-base.

local M = {}

---Close the Diffview view owning the current tab, if there is one.
---@return boolean closed true when a view was open and got closed
function M.close_if_open()
	if require("diffview.lib").get_current_view() then
		vim.cmd("DiffviewClose")
		return true
	end
	return false
end

return M

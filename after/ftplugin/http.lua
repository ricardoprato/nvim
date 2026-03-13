local kulala = require("kulala")
local map = function(lhs, rhs, desc)
	vim.keymap.set("n", lhs, rhs, { buffer = 0, desc = "Kulala: " .. desc })
end

map("<CR>", kulala.run, "Run request")
map("<leader>rr", kulala.run, "Run request")
map("[r", kulala.jump_prev, "Previous request")
map("]r", kulala.jump_next, "Next request")
map("<leader>ri", kulala.inspect, "Inspect request")
map("<leader>rt", kulala.toggle_view, "Toggle headers/body")
map("<leader>rc", kulala.copy, "Copy as cURL")
map("<leader>rp", kulala.from_curl, "Paste from cURL")
map("<leader>re", kulala.set_selected_env, "Select environment")

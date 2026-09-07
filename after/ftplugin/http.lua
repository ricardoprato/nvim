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

-- <leader>r is globally the "Replace" (grug-far) group; the maps above shadow
-- part of it here, so relabel the prefix buffer-locally — otherwise which-key
-- announces "Replace" over a menu that is entirely Kulala. Buffer-scoped, so
-- <leader>r stays "Replace" everywhere else. pcall: this ftplugin can run
-- before which-key's VeryLazy load when nvim opens an .http file directly.
pcall(function()
	require("which-key").add({ { "<leader>r", group = "Kulala", buffer = 0 } })
end)

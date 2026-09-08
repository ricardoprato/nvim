-- ┌────────────────────┐
-- │ LSP config example │
-- └────────────────────┘
--
-- This file contains configuration of 'lua_ls' language server.
-- Source: https://github.com/LuaLS/lua-language-server
--
-- It is used by `:h vim.lsp.enable()` and `:h vim.lsp.config()`.
-- See `:h vim.lsp.Config` and `:h vim.lsp.ClientConfig` for all available fields.
--
-- This config is designed for Lua's activity around Neovim. It provides only
-- basic config and can be further improved.
--
-- No `on_attach` here on purpose: completion is blink.cmp (lua/plugins/blink.lua),
-- so the server's own trigger characters are left untouched. Trimming them drops
-- the quote and slash triggers that drive `require("...")` path completion.
return {
	-- LuaLS Structure of these settings comes from LuaLS, not Neovim
	settings = {
		Lua = {
			-- Define runtime properties. Use 'LuaJIT', as it is built into Neovim.
			runtime = { version = "LuaJIT" },
			workspace = {
				-- Don't analyze code from submodules
				ignoreSubmodules = true,
				-- lazydev owns workspace.library, so suppress the "configure your
				-- environment as luv?" prompt and the .luarc.json it would write.
				checkThirdParty = false,
			},
		},
	},
}

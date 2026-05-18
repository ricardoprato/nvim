-- Dynamic colorscheme: read the active theme spec from the dotfiles pipeline.
-- The pipeline writes ~/.local/state/dotfiles/current-theme-dir/neovim.lua per
-- selected theme. That file returns a list of LazyVim plugin specs declaring
-- the right colorscheme plugin + LazyVim.colorscheme override.
--
-- Why dofile and not require: require would cache the result and miss future
-- theme switches if nvim is restarted with a stale package cache.

local theme_spec_path = vim.fn.expand("~/.local/state/dotfiles/current-theme-dir/neovim.lua")

if vim.uv.fs_stat(theme_spec_path) then
	local ok, specs = pcall(dofile, theme_spec_path)
	if ok and type(specs) == "table" then
		return specs
	end
end

-- Fallback when the dotfiles pipeline is not present (other machines, fresh installs)
return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 1000,
		config = function()
			require("catppuccin").setup({
				flavour = "auto",
				background = { light = "latte", dark = "mocha" },
				dim_inactive = { enabled = true, shade = "dark", percentage = 0.15 },
				default_integrations = true,
				auto_integrations = true,
			})
			vim.cmd.colorscheme("catppuccin-mocha")
		end,
	},
}

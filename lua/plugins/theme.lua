-- Dynamic colorscheme: read the active theme spec from the omarchy pipeline.
-- omarchy-theme-set stages ~/.local/state/omarchy/current/theme/neovim.lua per
-- selected theme (the user overlay in ~/.config/omarchy/themes/<theme>/ wins
-- over the upstream theme's own file). That file returns a list of LazyVim
-- plugin specs declaring the right colorscheme plugin + LazyVim.colorscheme
-- override.
--
-- Why dofile and not require: the file lives outside runtimepath and
-- package.path, so require cannot find it.

local theme_spec_path = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")

if vim.uv.fs_stat(theme_spec_path) then
	local ok, specs = pcall(dofile, theme_spec_path)
	if not ok then
		vim.notify(
			("theme: failed to load %s, using the fallback colorscheme: %s"):format(theme_spec_path, specs),
			vim.log.levels.ERROR
		)
	elseif type(specs) ~= "table" then
		vim.notify(
			("theme: %s returned %s instead of a spec table, using the fallback colorscheme"):format(
				theme_spec_path,
				type(specs)
			),
			vim.log.levels.WARN
		)
	else
		return specs
	end
end

-- Fallback when the omarchy pipeline is not present (other machines, fresh installs)
return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		-- Eager with top priority: the colorscheme must apply before the first
		-- redraw and before other plugins read highlight groups.
		lazy = false,
		priority = 1000,
		-- Only dim_inactive.enabled and auto_integrations differ from the plugin's
		-- defaults (auto_integrations is pinned on purpose).
		opts = {
			dim_inactive = { enabled = true },
			auto_integrations = true,
		},
		-- config instead of plain opts because the colorscheme must be applied
		-- after setup.
		config = function(_, opts)
			require("catppuccin").setup(opts)
			vim.cmd.colorscheme("catppuccin-mocha")
		end,
	},
}

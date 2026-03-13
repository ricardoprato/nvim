return {
  'catppuccin/nvim',
  name = 'catppuccin',
  lazy = false,
  priority = 1000,
  config = function()
    require('catppuccin').setup({
      flavour = 'auto',
      background = { light = 'latte', dark = 'mocha' },
      dim_inactive = {
        enabled = true,
        shade = 'dark',
        percentage = 0.15,
      },
      default_integrations = true,
      integrations = {
        mason = true,
        mini = { enabled = true, indentscope_color = 'mocha' },
        dap = true,
        noice = true,
        which_key = true,
        snacks = true,
      },
    })
    -- Note: changed from 'catppuccin-nvim' (repo-name artifact in mini.deps) to
    -- 'catppuccin-mocha' (correct Catppuccin flavour name, forces mocha in dark mode)
    vim.cmd.colorscheme('catppuccin-mocha')
  end,
}

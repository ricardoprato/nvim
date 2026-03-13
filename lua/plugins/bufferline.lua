return {
  'akinsho/bufferline.nvim',
  event = 'VeryLazy',
  opts = {
    options = {
      diagnostics = 'nvim_lsp',
      always_show_bufferline = true,
      separator_style = 'slant',
      show_buffer_close_icons = true,
      show_close_icon = false,
      offsets = {
        {
          filetype = 'snacks_layout_box',
          text = 'File Explorer',
          highlight = 'Directory',
          text_align = 'left',
        },
      },
    },
    highlights = function()
      return require('catppuccin.groups.integrations.bufferline').get()
    end,
  },
}

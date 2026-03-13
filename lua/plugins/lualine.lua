return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  config = function()
    -- Custom component: git branch + ahead/behind + conflicts
    local function git_status()
      local summary = vim.b.minigit_summary_string
      if summary and summary ~= '' then
        return summary
      end
      return ''
    end

    require('lualine').setup({
      options = {
        theme = 'catppuccin',
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        globalstatus = true,
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = {
          { git_status, icon = '' },
          'diff',
          'diagnostics',
        },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location', 'searchcount' },
      },
    })
  end,
}

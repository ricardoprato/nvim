return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    event = { 'BufReadPost', 'BufNewFile' },
    build = ':TSUpdate',
    config = function()
      local languages = {
        'lua', 'vimdoc', 'markdown', 'markdown_inline',
        'python', 'xml', 'html', 'css',
        'javascript', 'typescript', 'tsx', 'jsx', 'astro',
        'bash', 'json', 'yaml', 'toml',
        'dockerfile', 'gitcommit', 'diff', 'query', 'http',
      }
      local isnt_installed = function(lang)
        return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0
      end
      local to_install = vim.tbl_filter(isnt_installed, languages)
      if #to_install > 0 then
        require('nvim-treesitter').install(to_install)
      end

      local filetypes = {}
      for _, lang in ipairs(languages) do
        for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
          table.insert(filetypes, ft)
        end
      end
      _G.Config.new_autocmd('FileType', filetypes, function(ev)
        vim.treesitter.start(ev.buf)
      end, 'Start tree-sitter')
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    event = { 'BufReadPost', 'BufNewFile' },
  },
}

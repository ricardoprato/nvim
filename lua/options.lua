local default_options = {
  backup = false, -- creates a backup file
  clipboard = "unnamedplus", -- allows neovim to access the system clipboard
  cmdheight = 1, -- more space in the neovim command line for displaying messages
  completeopt = { "menuone", "noselect" },
  conceallevel = 0, -- so that `` is visible in markdown files
  fileencoding = "utf-8", -- the encoding written to a file
  foldmethod = "manual", -- folding, set to "expr" for treesitter based folding
  foldexpr = "", -- set to "nvim_treesitter#foldexpr()" for treesitter based folding
  guifont = "monospace:h17", -- the font used in graphical neovim applications
  hidden = true, -- required to keep multiple buffers and open multiple buffers
  hlsearch = true, -- highlight all matches on previous search pattern
  ignorecase = true, -- ignore case in search patterns
  mouse = "a", -- allow the mouse to be used in neovim
  pumheight = 10, -- pop up menu height
  showmode = false, -- we don't need to see things like -- INSERT -- anymore
  smartcase = true, -- smart case
  smartindent = true,                      -- make indenting smarter again
  showtabline = 0,                         -- always show tabs
  splitbelow = true, -- force all horizontal splits to go below current window
  splitright = true, -- force all vertical splits to go to the right of current window
  swapfile = false, -- creates a swapfile
  timeout = true,
  termguicolors = true, -- set term gui colors (most terminals support this)
  timeoutlen = 1000, -- time to wait for a mapped sequence to complete (in milliseconds)
  title = true, -- set the title of window to the value of the titlestring
  titlestring = "%<%F%=%l/%L - nvim", -- what the title of the window will be set to
  undofile = true, -- enable persistent undo
  updatetime = 100, -- faster completion
  writebackup = false, -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
  expandtab = true, -- convert tabs to spaces
  shiftwidth = 2, -- the number of spaces inserted for each indentation
  tabstop = 2, -- insert 2 spaces for a tab
  cursorline = true, -- highlight the current line
  number = true, -- set numbered lines
  numberwidth = 4, -- minimal number of columns to use for the line number {default 4}
  signcolumn = "yes", -- always show the sign column, otherwise it would shift the text each time
  wrap = false, -- display lines as one long line
  scrolloff = 8, -- minimal number of screen lines to keep above and below the cursor.
  sidescrolloff = 8, -- minimal number of screen columns to keep to the left and right of the cursor if wrap is `false`
  showcmd = false, -- hide (partial) command in the last line of the screen (for performance)
  ruler = false, -- hide the line and column number of the cursor position
  laststatus = 3, -- only the last window will always have a status line
  linebreak = true,  -- enable linebreak
}

---  SETTINGS  ---
vim.opt.spelllang:append "cjk" -- disable spellchecking for asian characters (VIM algorithm does not support it)
vim.opt.shortmess:append "c" -- don't show redundant messages from ins-completion-menu
vim.opt.shortmess:append "I" -- don't show the default intro message
vim.opt.whichwrap:append "<,>,[,],h,l"

-- Apply options
for k, v in pairs(default_options) do
  vim.opt[k] = v
end

vim.filetype.add {
  extension = {
    tex = "tex",
    zir = "zir",
    cr = "crystal",
  },
  pattern = {
    ["[jt]sconfig.*.json"] = "jsonc",
  },
}
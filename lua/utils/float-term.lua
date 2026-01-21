-- Floating terminal utility for lazygit, lazydocker, etc.
local M = {}

-- Store terminal state
M._terminals = {}

--- Create a floating window configuration
---@param opts? { width?: number, height?: number }
---@return table
local function create_float_config(opts)
  opts = opts or {}
  local width = opts.width or 0.9
  local height = opts.height or 0.9

  local columns = vim.o.columns
  local lines = vim.o.lines

  local win_width = math.floor(columns * width)
  local win_height = math.floor(lines * height)
  local row = math.floor((lines - win_height) / 2)
  local col = math.floor((columns - win_width) / 2)

  return {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  }
end

--- Open a floating terminal with the given command
---@param cmd string Command to run
---@param opts? { width?: number, height?: number, on_exit?: function }
function M.open(cmd, opts)
  opts = opts or {}

  -- Check if terminal already exists and is valid
  local term_info = M._terminals[cmd]
  if term_info and vim.api.nvim_buf_is_valid(term_info.buf) then
    -- Reopen existing terminal
    local float_config = create_float_config(opts)
    term_info.win = vim.api.nvim_open_win(term_info.buf, true, float_config)
    vim.cmd('startinsert')
    return
  end

  -- Create new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Create floating window
  local float_config = create_float_config(opts)
  local win = vim.api.nvim_open_win(buf, true, float_config)

  -- Start terminal with command
  vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code)
      -- Clean up when process exits
      M._terminals[cmd] = nil
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      if opts.on_exit then
        opts.on_exit(exit_code)
      end
    end,
  })

  -- Store terminal info
  M._terminals[cmd] = { buf = buf, win = win }

  -- Enter insert mode
  vim.cmd('startinsert')

  vim.keymap.set('t', 'q', function()
    -- Only close if the command supports 'q' to quit (lazygit, lazydocker do)
    -- Send 'q' to the terminal
    vim.api.nvim_feedkeys('q', 'n', false)
  end, { buffer = buf, desc = 'Quit application' })
end

--- Open lazygit in floating terminal
function M.lazygit()
  M.open('lazygit', { width = 0.95, height = 0.95 })
end

--- Open lazydocker in floating terminal
function M.lazydocker()
  M.open('lazydocker', { width = 0.95, height = 0.95 })
end

--- Open a generic floating terminal (shell)
function M.shell()
  M.open(vim.o.shell, { width = 0.9, height = 0.9 })
end

return M

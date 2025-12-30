-- ┌───────────────────────┐
-- │ DAP (Debug Adapter)   │
-- └───────────────────────┘
--
-- This file configures nvim-dap for debugging Python (Odoo) and JavaScript/TypeScript.
-- DAP (Debug Adapter Protocol) provides debugging capabilities in Neovim.
--
-- Usage:
-- - F5: Start/Continue debugging
-- - F9: Toggle breakpoint
-- - F10: Step over
-- - F11: Step into
-- - F7: Toggle DAP UI
--
-- See 'plugin/20_keymaps.lua' for all DAP keybindings.

local later = MiniDeps.later
local map = function(mode, lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

later(function()
  MiniDeps.add('mfussenegger/nvim-dap')
  MiniDeps.add('rcarriga/nvim-dap-ui')
  MiniDeps.add('nvim-neotest/nvim-nio') -- Required by dapui
  MiniDeps.add('theHamsta/nvim-dap-virtual-text')
  MiniDeps.add('mfussenegger/nvim-dap-python')
  MiniDeps.add('mxsdev/nvim-dap-vscode-js')

  local dap = require('dap')
  local dapui = require('dapui')

  -- DAP UI setup ===========================================================
  dapui.setup({
    layouts = {
      {
        elements = {
          { id = 'scopes',      size = 0.25 },
          { id = 'breakpoints', size = 0.25 },
          { id = 'stacks',      size = 0.25 },
          { id = 'watches',     size = 0.25 },
        },
        position = 'right',
        size = 30,
      },
      {
        elements = {
          { id = 'repl',    size = 0.5 },
          { id = 'console', size = 0.5 },
        },
        position = 'bottom',
        size = 8,
      },
    },
    floating = {
      border = 'rounded',
      mappings = { close = { 'q', '<Esc>' } },
    },
    mappings = {
      edit = 'e',
      expand = { '<CR>', '<2-LeftMouse>' },
      open = 'o',
      remove = 'd',
      repl = 'r',
      toggle = 't',
    },
  })

  -- Virtual text setup (show variable values inline) ======================
  require('nvim-dap-virtual-text').setup()

  -- Auto-open/close DAP UI =================================================
  dap.listeners.after.event_initialized['dapui_config'] = dapui.open
  dap.listeners.before.event_terminated['dapui_config'] = dapui.close
  dap.listeners.before.event_exited['dapui_config'] = dapui.close

  -- DAP signs ==============================================================
  local sign = vim.fn.sign_define
  sign('DapStopped', {
    text = '',
    texthl = 'DiagnosticSignWarn',
    linehl = 'Visual',
    numhl = 'DiagnosticSignWarn',
  })

  sign("DapBreakpoint", { text = "", texthl = "DapBreakpoint", linehl = "", numhl = "" })
  sign("DapBreakpointRejected", { text = "", texthl = "DapBreakpoint", linehl = "", numhl = "" })
  sign("DapBreakpointCondition", { text = "", texthl = "DapBreakpointCondition", linehl = "", numhl = "" })
  sign("DapLogPoint", { text = "◆", texthl = "DapLogPoint", linehl = "", numhl = "" })
  sign("DapStopped", { text = "", texthl = "DapLogPoint", linehl = "", numhl = "" })
  -- Python debugger (for Odoo) =============================================
  local debugpy_path = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python'
  require('dap-python').setup(debugpy_path)

  -- JavaScript/TypeScript debugger =========================================
  require('dap-vscode-js').setup({
    node_path = 'node',
    debugger_path = vim.fn.stdpath('data') .. '/mason/packages/js-debug-adapter',
    adapters = { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'pwa-extensionHost', 'node-terminal' },
  })

  -- Helper: Check if Deno project ==========================================
  local function is_deno_project()
    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file == '' then
      return false
    end
    local current_dir = vim.fn.fnamemodify(current_file, ':h')
    local util = require('lspconfig.util')
    return util.root_pattern('deno.json', 'deno.jsonc')(current_dir) ~= nil
  end

  -- JavaScript configurations (Node.js vs Deno) ============================
  dap.configurations.javascript = {
    {
      type = 'pwa-node',
      request = 'launch',
      name = 'Launch file (Node.js)',
      program = '${file}',
      cwd = '${workspaceFolder}',
      condition = function()
        return not is_deno_project()
      end,
    },
    {
      type = 'pwa-node',
      request = 'attach',
      name = 'Attach (Node.js)',
      processId = require('dap.utils').pick_process,
      cwd = '${workspaceFolder}',
      condition = function()
        return not is_deno_project()
      end,
    },
  }

  -- Share configs across JS/TS filetypes ===================================
  dap.configurations.typescript = dap.configurations.javascript
  dap.configurations.typescriptreact = dap.configurations.javascript
  dap.configurations.javascriptreact = dap.configurations.javascript

  -- Automatically load .vscode/launch.json configurations ==================
  local load_launchjs = function()
    local ok, vscode = pcall(require, 'dap.ext.vscode')
    if ok then
      vscode.load_launchjs()
    end
  end
  _G.Config.new_autocmd({ 'VimEnter', 'FileType', 'BufEnter', 'WinEnter' }, nil, load_launchjs, 'Load launch.json')

  map('v', '<F2>', function ()
    require('dapui').eval()
  end, 'Debug: Evaluate Input')
  map('n', '<F5>', function ()
    require('dap').continue()
  end, 'Debug: Start/Continue')
  map('n', '<S-F5>', function ()
    require('dap').terminate()
  end, 'Debug: Stop')
  map('n', '<C-F5>', function ()
    require('dap').restart_frame()
  end, 'Debug: Restart')
  map('n', '<F6>', function ()
    require('dap').pause()
  end, 'Debug: Pause')
  map('n', '<F7>', function ()
    require('dapui').toggle()
  end, 'Debug: Toggle Debug UI')
  map('n', '<F9>', function ()
    require('dap').toggle_breakpoint()
  end, 'Debug: Toggle Breakpoint')
  map('n', '<S-F9>', function ()
    require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
  end, 'Debug: Set Breakpoint')
  map('n', '<F10>', function ()
    require('dap').step_over()
  end, 'Debug: Step Over')
  map('n', '<F11>', function ()
    require('dap').step_into()
  end, 'Debug: Step Into')
  map('n', '<S-F11>', function ()
    require('dap').step_out()
  end, 'Debug: Step Out')
  map('n', '<leader>du', function ()
    require('dapui').toggle()
  end, 'Debug: Toggle Debug UI (F7)')
  map('n', '<leader>dh', function ()
    require('dap.ui.widgets').hover()
  end, 'Debug: Hover')
  map('n', '<leader>de', function ()
    require('dapui').eval()
  end, 'Debug: Evaluate Input (F2)')
  map('n', '<leader>de', function ()
    require('dap').set_exception_breakpoints()
  end, 'Debug: Set Exception Breakpoints')
  map('n', '<leader>da', function ()
    require('dap').set_exception_breakpoints()
  end, 'Debug: Set Exception Breakpoints')
  map('n', '<leader>dc', function ()
    require('dap').continue()
  end, 'Debug: Start/Continue (F5)')
  map('n', '<leader>dQ', function ()
    require('dap').terminate()
  end, 'Debug: Stop (<S-F5>)')
  map('n', '<leader>dQ', function ()
    require('dap').terminate()
  end, 'Debug: Stop (<S-F5>)')
  map('n', '<leader>dr', function ()
    require('dap').restart()
  end, 'Debug: Restart (<C-F5>)')
  map('n', '<leader>dp', function ()
    require('dap').pause()
  end, 'Debug: Pause (<F6>)')
  map('n', '<leader>dR', function ()
    require('dap').repl.toggle()
  end, 'Debug: Toggle REPL')
  map('n', '<leader>ds', function ()
    require('dap').run_to_cursor()
  end, 'Debug: Run to Cursor')
  map('n', '<leader>dB', function ()
    require('dap').clear_breakpoints()
  end, 'Debug: Clear Breakpoints')
  map('n', '<leader>db', function ()
    require('dap').toggle_breakpoint()
  end, 'Debug: Toggle Breakpoint (F9)')
  map('n', '<leader>dC', function ()
    require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
  end, 'Debug: Set Conditional Breakpoint (<S-F9>)')
  map('n', '<leader>do', function ()
    require('dap').step_over()
  end, 'Debug: Step Over (F10)')
  map('n', '<leader>di', function ()
    require('dap').step_into()
  end, 'Debug: Step Into (F11)')
  map('n', '<leader>dO', function ()
    require('dap').step_out()
  end, 'Debug: Step Out (<S-F11>)')
end)

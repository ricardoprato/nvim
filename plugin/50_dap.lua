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
  sign("DapBreakpoint", { text = "", texthl = "DapBreakpoint", linehl = "", numhl = "" })
  sign("DapBreakpointRejected", { text = "", texthl = "DapBreakpoint", linehl = "", numhl = "" })
  sign("DapBreakpointCondition", { text = "", texthl = "DapBreakpointCondition", linehl = "", numhl = "" })
  sign("DapLogPoint", { text = "◆", texthl = "DapLogPoint", linehl = "", numhl = "" })
  sign("DapStopped", { text = "", texthl = "DiagnosticSignWarn", linehl = "Visual", numhl = "DiagnosticSignWarn" })
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

  -- React Native/Expo configurations ========================================
  -- Helper: Check if React Native project
  local function is_react_native_project()
    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file == '' then return false end
    local current_dir = vim.fn.fnamemodify(current_file, ':h')
    local util = require('lspconfig.util')
    return util.root_pattern('app.json', 'app.config.js', 'app.config.ts', 'metro.config.js')(current_dir) ~= nil
  end

  -- React Native specific debug configurations
  local react_native_configs = {
    {
      type = 'pwa-node',
      request = 'attach',
      name = 'Attach to React Native (Hermes)',
      port = 8081,
      cwd = '${workspaceFolder}',
      sourceMaps = true,
      protocol = 'inspector',
      localRoot = '${workspaceFolder}',
      remoteRoot = '${workspaceFolder}',
    },
    {
      type = 'pwa-node',
      request = 'attach',
      name = 'Attach to Expo (Metro)',
      port = 19000,
      cwd = '${workspaceFolder}',
      sourceMaps = true,
      protocol = 'inspector',
      localRoot = '${workspaceFolder}',
      remoteRoot = '${workspaceFolder}',
    },
    {
      type = 'pwa-chrome',
      request = 'launch',
      name = 'Debug in Chrome (Expo Web)',
      url = 'http://localhost:19006',
      webRoot = '${workspaceFolder}',
      sourceMaps = true,
    },
  }

  -- Merge React Native configs with existing JS configs
  for _, config in ipairs(react_native_configs) do
    table.insert(dap.configurations.javascript, config)
  end

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

  -- DAP Keymaps (declarative) ================================================
  local keymaps = {
    -- Function keys
    { 'v', '<F2>',       dapui.eval,                                                     'Evaluate Input' },
    { 'n', '<F5>',       dap.continue,                                                   'Start/Continue' },
    { 'n', '<S-F5>',     dap.terminate,                                                  'Stop' },
    { 'n', '<C-F5>',     dap.restart_frame,                                              'Restart' },
    { 'n', '<F6>',       dap.pause,                                                      'Pause' },
    { 'n', '<F7>',       dapui.toggle,                                                   'Toggle UI' },
    { 'n', '<F9>',       dap.toggle_breakpoint,                                          'Toggle Breakpoint' },
    { 'n', '<S-F9>',     function() dap.set_breakpoint(vim.fn.input('Condition: ')) end, 'Conditional Breakpoint' },
    { 'n', '<F10>',      dap.step_over,                                                  'Step Over' },
    { 'n', '<F11>',      dap.step_into,                                                  'Step Into' },
    { 'n', '<S-F11>',    dap.step_out,                                                   'Step Out' },
    -- Leader keys
    { 'n', '<leader>du', dapui.toggle,                                                   'Toggle UI (F7)' },
    { 'n', '<leader>dh', function() require('dap.ui.widgets').hover() end,               'Hover' },
    { 'n', '<leader>de', dapui.eval,                                                     'Evaluate (F2)' },
    { 'n', '<leader>da', dap.set_exception_breakpoints,                                  'Exception Breakpoints' },
    { 'n', '<leader>dc', dap.continue,                                                   'Continue (F5)' },
    { 'n', '<leader>dQ', dap.terminate,                                                  'Stop (S-F5)' },
    { 'n', '<leader>dr', dap.restart,                                                    'Restart (C-F5)' },
    { 'n', '<leader>dp', dap.pause,                                                      'Pause (F6)' },
    { 'n', '<leader>dR', dap.repl.toggle,                                                'Toggle REPL' },
    { 'n', '<leader>ds', dap.run_to_cursor,                                              'Run to Cursor' },
    { 'n', '<leader>dB', dap.clear_breakpoints,                                          'Clear Breakpoints' },
    { 'n', '<leader>db', dap.toggle_breakpoint,                                          'Toggle Breakpoint (F9)' },
    { 'n', '<leader>dC', function() dap.set_breakpoint(vim.fn.input('Condition: ')) end, 'Conditional Breakpoint (S-F9)' },
    { 'n', '<leader>do', dap.step_over,                                                  'Step Over (F10)' },
    { 'n', '<leader>di', dap.step_into,                                                  'Step Into (F11)' },
    { 'n', '<leader>dO', dap.step_out,                                                   'Step Out (S-F11)' },
  }

  for _, km in ipairs(keymaps) do
    map(km[1], km[2], km[3], 'Debug: ' .. km[4])
  end
end)
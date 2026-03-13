return {
  'mfussenegger/nvim-dap',
  cmd = { 'DapContinue', 'DapToggleBreakpoint' },
  keys = {
    { '<F5>', function() require('dap').continue() end, desc = 'Debug: Start/Continue' },
    { '<F9>', function() require('dap').toggle_breakpoint() end, desc = 'Debug: Toggle Breakpoint' },
    { '<leader>dc', function() require('dap').continue() end, desc = 'Debug: Continue (F5)' },
    { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Debug: Toggle Breakpoint (F9)' },
  },
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',
    'theHamsta/nvim-dap-virtual-text',
    'mfussenegger/nvim-dap-python',
    'mxsdev/nvim-dap-vscode-js',
  },
  config = function()
    local dap = require('dap')
    local dapui = require('dapui')

    dapui.setup({
      layouts = {
        {
          elements = {
            { id = 'scopes', size = 0.25 },
            { id = 'breakpoints', size = 0.25 },
            { id = 'stacks', size = 0.25 },
            { id = 'watches', size = 0.25 },
          },
          position = 'right',
          size = 30,
        },
        {
          elements = {
            { id = 'repl', size = 0.5 },
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

    require('nvim-dap-virtual-text').setup()

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    local sign = vim.fn.sign_define
    sign('DapBreakpoint', { text = '', texthl = 'DapBreakpoint', linehl = '', numhl = '' })
    sign('DapBreakpointRejected', { text = '', texthl = 'DapBreakpoint', linehl = '', numhl = '' })
    sign('DapBreakpointCondition', { text = '', texthl = 'DapBreakpointCondition', linehl = '', numhl = '' })
    sign('DapLogPoint', { text = '◆', texthl = 'DapLogPoint', linehl = '', numhl = '' })
    sign('DapStopped', { text = '', texthl = 'DiagnosticSignWarn', linehl = 'Visual', numhl = 'DiagnosticSignWarn' })

    local debugpy_path = vim.fn.stdpath('data') .. '/mason/packages/debugpy/venv/bin/python'
    require('dap-python').setup(debugpy_path)

    require('dap-vscode-js').setup({
      node_path = 'node',
      debugger_path = vim.fn.stdpath('data') .. '/mason/packages/js-debug-adapter',
      adapters = { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'pwa-extensionHost', 'node-terminal' },
    })

    local function is_deno_project()
      local current_file = vim.api.nvim_buf_get_name(0)
      if current_file == '' then return false end
      local current_dir = vim.fn.fnamemodify(current_file, ':h')
      local util = require('lspconfig.util')
      return util.root_pattern('deno.json', 'deno.jsonc')(current_dir) ~= nil
    end

    dap.configurations.javascript = {
      {
        type = 'pwa-node', request = 'launch', name = 'Launch file (Node.js)',
        program = '${file}', cwd = '${workspaceFolder}',
        condition = function() return not is_deno_project() end,
      },
      {
        type = 'pwa-node', request = 'attach', name = 'Attach (Node.js)',
        processId = require('dap.utils').pick_process, cwd = '${workspaceFolder}',
        condition = function() return not is_deno_project() end,
      },
      {
        type = 'pwa-node', request = 'attach', name = 'Attach to React Native (Hermes)',
        port = 8081, cwd = '${workspaceFolder}', sourceMaps = true,
        protocol = 'inspector', localRoot = '${workspaceFolder}', remoteRoot = '${workspaceFolder}',
      },
      {
        type = 'pwa-node', request = 'attach', name = 'Attach to Expo (Metro)',
        port = 19000, cwd = '${workspaceFolder}', sourceMaps = true,
        protocol = 'inspector', localRoot = '${workspaceFolder}', remoteRoot = '${workspaceFolder}',
      },
      {
        type = 'pwa-chrome', request = 'launch', name = 'Debug in Chrome (Expo Web)',
        url = 'http://localhost:19006', webRoot = '${workspaceFolder}', sourceMaps = true,
      },
    }

    dap.configurations.typescript = dap.configurations.javascript
    dap.configurations.typescriptreact = dap.configurations.javascript
    dap.configurations.javascriptreact = dap.configurations.javascript

    local vscode = require('dap.ext.vscode')
    dap.providers.configs['dap.launch.json'] = function(bufnr)
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname == '' then return {} end
      local dir = vim.fn.fnamemodify(bufname, ':p:h')
      local launch_json = vim.fs.find('.vscode/launch.json', { path = dir, upward = true, type = 'file' })[1]
      if not launch_json then return {} end
      return vscode.getconfigs(launch_json)
    end

    -- Remaining keymaps (those not in keys={} above)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { desc = 'Debug: ' .. desc })
    end
    map('v', '<F2>', dapui.eval, 'Evaluate Input')
    map('n', '<S-F5>', dap.terminate, 'Stop')
    map('n', '<C-F5>', dap.restart_frame, 'Restart')
    map('n', '<F6>', dap.pause, 'Pause')
    map('n', '<F7>', dapui.toggle, 'Toggle UI')
    map('n', '<S-F9>', function() dap.set_breakpoint(vim.fn.input('Condition: ')) end, 'Conditional Breakpoint')
    map('n', '<F10>', dap.step_over, 'Step Over')
    map('n', '<F11>', dap.step_into, 'Step Into')
    map('n', '<S-F11>', dap.step_out, 'Step Out')
    map('n', '<leader>du', dapui.toggle, 'Toggle UI (F7)')
    map('n', '<leader>dh', function() require('dap.ui.widgets').hover() end, 'Hover')
    map('n', '<leader>de', dapui.eval, 'Evaluate (F2)')
    map('n', '<leader>da', dap.set_exception_breakpoints, 'Exception Breakpoints')
    map('n', '<leader>dQ', dap.terminate, 'Stop (S-F5)')
    map('n', '<leader>dr', dap.restart, 'Restart (C-F5)')
    map('n', '<leader>dp', dap.pause, 'Pause (F6)')
    map('n', '<leader>dR', dap.repl.toggle, 'Toggle REPL')
    map('n', '<leader>ds', dap.run_to_cursor, 'Run to Cursor')
    map('n', '<leader>dB', dap.clear_breakpoints, 'Clear Breakpoints')
    map('n', '<leader>dC', function() dap.set_breakpoint(vim.fn.input('Condition: ')) end, 'Conditional Breakpoint (S-F9)')
    map('n', '<leader>do', dap.step_over, 'Step Over (F10)')
    map('n', '<leader>di', dap.step_into, 'Step Into (F11)')
    map('n', '<leader>dO', dap.step_out, 'Step Out (S-F11)')
  end,
}

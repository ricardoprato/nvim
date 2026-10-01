local function conditional_breakpoint()
	require("dap").set_breakpoint(vim.fn.input("Condition: "))
end

return {
	"mfussenegger/nvim-dap",
	cmd = { "DapContinue", "DapToggleBreakpoint" },
	keys = {
		-- Teclas de funcion (estilo IDE)
		{
			"<F5>",
			function()
				require("dap").continue()
			end,
			desc = "Debug: Start/Continue",
		},
		{
			"<S-F5>",
			function()
				require("dap").terminate()
			end,
			desc = "Debug: Stop",
		},
		{
			"<C-F5>",
			function()
				require("dap").restart_frame()
			end,
			desc = "Debug: Restart Frame",
		},
		{
			"<F6>",
			function()
				require("dap").pause()
			end,
			desc = "Debug: Pause",
		},
		{
			"<F7>",
			function()
				require("dapui").toggle()
			end,
			desc = "Debug: Toggle UI",
		},
		{
			"<F9>",
			function()
				require("dap").toggle_breakpoint()
			end,
			desc = "Debug: Toggle Breakpoint",
		},
		{ "<S-F9>", conditional_breakpoint, desc = "Debug: Conditional Breakpoint" },
		{
			"<F10>",
			function()
				require("dap").step_over()
			end,
			desc = "Debug: Step Over",
		},
		{
			"<F11>",
			function()
				require("dap").step_into()
			end,
			desc = "Debug: Step Into",
		},
		{
			"<S-F11>",
			function()
				require("dap").step_out()
			end,
			desc = "Debug: Step Out",
		},
		{
			"<F2>",
			function()
				require("dapui").eval()
			end,
			mode = { "n", "v" },
			desc = "Debug: Evaluate",
		},

		-- Grupo <leader>d
		{
			"<leader>dc",
			function()
				require("dap").continue()
			end,
			desc = "Debug: Continue (F5)",
		},
		{
			"<leader>db",
			function()
				require("dap").toggle_breakpoint()
			end,
			desc = "Debug: Toggle Breakpoint (F9)",
		},
		{ "<leader>dC", conditional_breakpoint, desc = "Debug: Conditional Breakpoint (S-F9)" },
		{
			"<leader>dB",
			function()
				require("dap").clear_breakpoints()
			end,
			desc = "Debug: Clear Breakpoints",
		},
		{
			"<leader>da",
			function()
				require("dap").set_exception_breakpoints()
			end,
			desc = "Debug: Exception Breakpoints",
		},
		{
			"<leader>du",
			function()
				require("dapui").toggle()
			end,
			desc = "Debug: Toggle UI (F7)",
		},
		{
			"<leader>de",
			function()
				require("dapui").eval()
			end,
			mode = { "n", "v" },
			desc = "Debug: Evaluate (F2)",
		},
		{
			"<leader>dh",
			function()
				require("dap.ui.widgets").hover()
			end,
			desc = "Debug: Hover",
		},
		{
			"<leader>dR",
			function()
				require("dap").repl.toggle()
			end,
			desc = "Debug: Toggle REPL",
		},
		{
			"<leader>dQ",
			function()
				require("dap").terminate()
			end,
			desc = "Debug: Stop (S-F5)",
		},
		{
			"<leader>dr",
			function()
				require("dap").restart()
			end,
			desc = "Debug: Restart Session",
		},
		{
			"<leader>dp",
			function()
				require("dap").pause()
			end,
			desc = "Debug: Pause (F6)",
		},
		{
			"<leader>ds",
			function()
				require("dap").run_to_cursor()
			end,
			desc = "Debug: Run to Cursor",
		},
		{
			"<leader>do",
			function()
				require("dap").step_over()
			end,
			desc = "Debug: Step Over (F10)",
		},
		{
			"<leader>di",
			function()
				require("dap").step_into()
			end,
			desc = "Debug: Step Into (F11)",
		},
		{
			"<leader>dO",
			function()
				require("dap").step_out()
			end,
			desc = "Debug: Step Out (S-F11)",
		},
	},
	dependencies = {
		"rcarriga/nvim-dap-ui",
		"nvim-neotest/nvim-nio",
		"theHamsta/nvim-dap-virtual-text",
		"mfussenegger/nvim-dap-python",
	},
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")

		dapui.setup({
			layouts = {
				{
					elements = {
						{ id = "scopes", size = 0.25 },
						{ id = "breakpoints", size = 0.25 },
						{ id = "stacks", size = 0.25 },
						{ id = "watches", size = 0.25 },
					},
					position = "right",
					size = 30,
				},
				{
					elements = {
						{ id = "repl", size = 0.5 },
						{ id = "console", size = 0.5 },
					},
					position = "bottom",
					size = 8,
				},
			},
			floating = {
				border = "rounded",
				mappings = { close = { "q", "<Esc>" } },
			},
			mappings = {
				edit = "e",
				expand = { "<CR>", "<2-LeftMouse>" },
				open = "o",
				remove = "d",
				repl = "r",
				toggle = "t",
			},
		})

		require("nvim-dap-virtual-text").setup()

		dap.listeners.after.event_initialized["dapui_config"] = dapui.open
		dap.listeners.before.event_terminated["dapui_config"] = dapui.close
		dap.listeners.before.event_exited["dapui_config"] = dapui.close

		local sign = vim.fn.sign_define
		sign("DapBreakpoint", { text = "", texthl = "DapBreakpoint", linehl = "", numhl = "" })
		sign("DapBreakpointRejected", { text = "", texthl = "DiagnosticSignWarn", linehl = "", numhl = "" })
		sign("DapBreakpointCondition", { text = "", texthl = "DapBreakpointCondition", linehl = "", numhl = "" })
		sign("DapLogPoint", { text = "◆", texthl = "DapLogPoint", linehl = "", numhl = "" })
		sign("DapStopped", { text = "", texthl = "DiagnosticSignWarn", linehl = "CursorLine", numhl = "" })

		local debugpy_path = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
		require("dap-python").setup(debugpy_path)

		-- Like its language server, Godot hosts the debug adapter inside the
		-- editor (Editor Settings > Network > Debug Adapter, port 6006), so there
		-- is no executable to launch: nvim-dap only connects to the running editor.
		dap.adapters.godot = { type = "server", host = "127.0.0.1", port = 6006 }
		dap.configurations.gdscript = {
			{ type = "godot", request = "launch", name = "Launch Godot scene", project = "${workspaceFolder}" },
		}

		local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"

		dap.adapters.codelldb = { type = "executable", command = mason_bin .. "codelldb" }
		dap.configurations.rust = {
			{
				type = "codelldb",
				request = "launch",
				name = "Launch Cargo binary",
				-- codelldb debugs a built binary, it does not run `cargo build`:
				-- build first, then pick the executable under target/debug.
				program = function()
					return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
				end,
				cwd = "${workspaceFolder}",
			},
		}

		-- js-debug only runs as a DAP server on a port, so nvim-dap spawns it
		-- and connects. Both adapter types share the same server. The host is passed
		-- explicitly because js-debug binds to ::1 by default, which a 127.0.0.1
		-- client never reaches.
		local js_debug = {
			type = "server",
			host = "127.0.0.1",
			port = "${port}",
			executable = { command = mason_bin .. "js-debug-adapter", args = { "${port}", "127.0.0.1" } },
		}
		dap.adapters["pwa-node"] = js_debug
		dap.adapters["pwa-chrome"] = js_debug
		-- VS Code launch.json files name these types `node` and `chrome`; alias
		-- them so the launch.json provider below can run those configs as is.
		dap.adapters.node = js_debug
		dap.adapters.chrome = js_debug

		local js_configs = {
			{
				type = "pwa-node",
				request = "launch",
				name = "Launch current file (Node)",
				program = "${file}",
				cwd = "${workspaceFolder}",
			},
			{
				-- Electron main process: start it with `electron --inspect=9229 .`
				type = "pwa-node",
				request = "attach",
				name = "Attach to Node/Electron main (9229)",
				port = 9229,
				cwd = "${workspaceFolder}",
			},
			{
				-- Electron renderer or a browser: start it with --remote-debugging-port=9222
				type = "pwa-chrome",
				request = "attach",
				name = "Attach to Chrome/Electron renderer (9222)",
				port = 9222,
				webRoot = "${workspaceFolder}",
			},
		}
		for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
			dap.configurations[ft] = js_configs
		end

		-- El provider built-in solo mira ./.vscode/launch.json en el cwd.
		-- Este busca hacia arriba desde el archivo del buffer.
		local vscode = require("dap.ext.vscode")
		dap.providers.configs["dap.launch.json"] = function(bufnr)
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			if bufname == "" then
				return {}
			end
			local dir = vim.fn.fnamemodify(bufname, ":p:h")
			local launch_json = vim.fs.find(".vscode/launch.json", { path = dir, upward = true, type = "file" })[1]
			if not launch_json then
				return {}
			end
			return vscode.getconfigs(launch_json)
		end
	end,
}

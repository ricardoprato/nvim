local M = {}

--- Toggle a vim option
--- @param option string The option name (e.g., 'spell', 'wrap', 'number')
--- @param scope? 'local'|'global' Scope of the option (default: 'local')
--- @return boolean The new value
M.option = function(option, scope)
  scope = scope or 'local'

  local opt = scope == 'global' and vim.o or vim.opt_local
  local current = opt[option]:get()

  -- Toggle boolean options
  if type(current) == 'boolean' then
    opt[option] = not current
    local new_value = not current
    vim.notify(
      string.format('%s %s: %s', scope, option, new_value and 'enabled' or 'disabled'),
      vim.log.levels.INFO
    )
    return new_value
  end

  vim.notify('Option is not boolean', vim.log.levels.WARN)
  return current
end

--- Toggle format on save (using conform.nvim)
--- @param scope? 'buffer'|'global' Scope of the toggle (default: 'buffer')
--- @return boolean The new state (true = enabled, false = disabled)
M.format = function(scope)
  scope = scope or 'buffer'

  if scope == 'buffer' then
    local bufnr = vim.api.nvim_get_current_buf()
    local current = vim.b[bufnr].disable_autoformat
    vim.b[bufnr].disable_autoformat = not current
    local enabled = not vim.b[bufnr].disable_autoformat

    vim.notify(
      string.format('Format on save (buffer): %s', enabled and 'enabled' or 'disabled'),
      vim.log.levels.INFO
    )
    return enabled
  elseif scope == 'global' then
    local current = vim.g.disable_autoformat
    vim.g.disable_autoformat = not current
    local enabled = not vim.g.disable_autoformat

    vim.notify(
      string.format('Format on save (global): %s', enabled and 'enabled' or 'disabled'),
      vim.log.levels.INFO
    )
    return enabled
  end
end

--- Toggle diagnostic display
--- @param scope? 'buffer'|'global' Scope of the toggle (default: 'buffer')
--- @return boolean The new state (true = enabled, false = disabled)
M.diagnostics = function(scope)
  scope = scope or 'buffer'

  if scope == 'buffer' then
    local bufnr = vim.api.nvim_get_current_buf()
    local current = vim.diagnostic.is_enabled({ bufnr = bufnr })

    if current then
      vim.diagnostic.enable(false, { bufnr = bufnr })
      vim.notify('Diagnostics (buffer): disabled', vim.log.levels.INFO)
      return false
    else
      vim.diagnostic.enable(true, { bufnr = bufnr })
      vim.notify('Diagnostics (buffer): enabled', vim.log.levels.INFO)
      return true
    end
  elseif scope == 'global' then
    local current = vim.diagnostic.is_enabled()

    if current then
      vim.diagnostic.enable(false)
      vim.notify('Diagnostics (global): disabled', vim.log.levels.INFO)
      return false
    else
      vim.diagnostic.enable(true)
      vim.notify('Diagnostics (global): enabled', vim.log.levels.INFO)
      return true
    end
  end
end

--- Toggle LSP inlay hints
--- @param bufnr? number Buffer number (default: current buffer)
--- @return boolean The new state (true = enabled, false = disabled)
M.inlay_hints = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local current = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })

  vim.lsp.inlay_hint.enable(not current, { bufnr = bufnr })

  vim.notify(
    string.format('Inlay hints: %s', not current and 'enabled' or 'disabled'),
    vim.log.levels.INFO
  )

  return not current
end

--- Generic toggle for buffer or global variables
--- @param var_name string The variable name
--- @param scope 'buffer'|'global' Scope of the variable
--- @param display_name? string Display name for notifications (default: var_name)
--- @return boolean The new value
M.variable = function(var_name, scope, display_name)
  display_name = display_name or var_name

  if scope == 'buffer' then
    local bufnr = vim.api.nvim_get_current_buf()
    local current = vim.b[bufnr][var_name]
    vim.b[bufnr][var_name] = not current
    local new_value = not current

    vim.notify(
      string.format('%s (buffer): %s', display_name, new_value and 'enabled' or 'disabled'),
      vim.log.levels.INFO
    )
    return new_value
  elseif scope == 'global' then
    local current = vim.g[var_name]
    vim.g[var_name] = not current
    local new_value = not current

    vim.notify(
      string.format('%s (global): %s', display_name, new_value and 'enabled' or 'disabled'),
      vim.log.levels.INFO
    )
    return new_value
  end
end

return M

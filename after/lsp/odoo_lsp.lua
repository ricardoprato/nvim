return {
  on_attach = function(client, buf_id)
    if not client then
      return
    end
    -- Pyright: sin hover
    if client.name == 'pyright' then
      client.server_capabilities.hoverProvider = false
    end
  end,
  cmd = { 'odoo-lsp' },
  root_dir = function(fname)
    return vim.fs.root(fname, { '.odoo_lsp', '.odoo_lsp.json' })
  end,
  filetypes = { 'javascript', 'xml', 'python' },
}

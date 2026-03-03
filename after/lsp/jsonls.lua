local ok, schemastore = pcall(require, 'schemastore')

return {
  settings = {
    json = {
      format = {
        enable = true,
      },
      schemas = ok and schemastore.json.schemas() or {},
      validate = { enable = true },
    },
  },
}

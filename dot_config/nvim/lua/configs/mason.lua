dofile(vim.g.base46_cache .. "mason")

return {
  PATH = "skip",

  ui = {
    icons = {
      package_pending = " ",
      package_installed = " ",
      package_uninstalled = " ",
    },
  },

  registries = {
    "github:nvim-java/mason-registry",
    "github:mason-org/mason-registry",
  },

  max_concurrent_installers = 10,
}

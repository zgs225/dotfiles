local opts = require "nvchad.configs.treesitter"

opts.ensure_installed = {
  "lua",
  "luadoc",
  "printf",
  "vim",
  "vimdoc",
  "go",
  "gomod",
  "gosum",
  "gowork",
  "gotmpl",
  "goctl",
  "python",
  "pymanifest",
  "rust",
  "proto",
  "yaml",
  "json",
  "xml",
  "csv",
  "javascript",
  "typescript",
}

return opts

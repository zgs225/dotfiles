local opts = require "nvchad.configs.treesitter"

-- 预装 parser 列表：nvim 启动时由 nvim-treesitter 自动 ensure_installed。
-- 增删 parser 直接改这里即可；新增项下次启动会自动安装，
-- 也可手动执行 `:TSInstall <lang>` / `:TSUpdate` 立即生效。
opts.ensure_installed = {
  -- 核心语言：Go / Python / C 系 / Node.js / TypeScript / CSS / HTML / Java
  "go",
  "gomod",
  "gosum",
  "gowork",
  "gotmpl",
  "python",
  "c",
  "cpp",
  "javascript",
  "typescript",
  "tsx",
  "astro",
  "css",
  "scss",
  "html",
  "java",
  "xml", -- Maven pom.xml 等

  -- 配置 / 数据格式
  "json",
  "yaml",
  "toml",
  "proto",
  "yuck", -- eww 配置语言

  -- 脚本
  "bash",
  "lua",

  -- Markdown（render-markdown.nvim 依赖 markdown / markdown_inline）
  "markdown",
  "markdown_inline",

  -- Git
  "git_config",
  "git_rebase",
  "gitattributes",
  "gitcommit",
  "gitignore",

  -- 构建 / 工具
  "dockerfile",
  "make",
  "diff",
  "regex",

  -- Neovim / treesitter 自身
  "vim",
  "vimdoc",
  "query",
}

return opts

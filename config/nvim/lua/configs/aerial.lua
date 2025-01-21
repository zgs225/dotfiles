require("aerial").setup {
  -- 布局配置
  layout = {
    max_width = { 40, 0.3 }, -- 最大宽度为40列或30%的编辑器宽度
    min_width = 30, -- 最小宽度为30列
    default_direction = "prefer_right", -- 默认在右侧打开
    placement = "window", -- 在当前窗口的右侧打开
    resize_to_content = true, -- 根据内容调整窗口大小
    preserve_equality = false, -- 不保持窗口大小相等
  },

  -- 自动关闭事件
  close_automatic_events = { "unsupported" },

  -- 过滤显示的符号类型
  filter_kind = {
    "Class",
    "Constant",
    "Constructor",
    "Enum",
    "EnumMember",
    "Field",
    "Function",
    "Interface",
    "Method",
    "Module",
    "Struct",
  },

  -- 高亮模式
  highlight_mode = "split_width", -- 每个窗口的光标位置都会在 aerial 窗口中部分高亮
  highlight_closest = true, -- 高亮最接近的符号
  highlight_on_hover = false, -- 不在悬停时高亮符号
  highlight_on_jump = 300, -- 跳转时高亮符号300ms

  -- 自动跳转
  autojump = false, -- 不自动跳转到符号

  -- 折叠管理
  manage_folds = false, -- 不管理折叠
  link_folds_to_tree = false, -- 不将折叠与树结构链接
  link_tree_to_folds = true, -- 将树结构与折叠链接

  -- 自动打开 aerial
  open_automatic = false, -- 不自动打开 aerial

  -- 显示引导线
  show_guides = false, -- 不显示引导线

  -- 浮动窗口配置
  float = {
    border = "rounded", -- 圆角边框
    relative = "cursor", -- 在光标位置打开浮动窗口
    max_height = 0.9, -- 最大高度为90%的编辑器高度
    min_height = { 8, 0.1 }, -- 最小高度为8行或10%的编辑器高度
  },

  -- 导航窗口配置
  nav = {
    border = "rounded", -- 圆角边框
    max_height = 0.9, -- 最大高度为90%的编辑器高度
    min_height = { 10, 0.1 }, -- 最小高度为10行或10%的编辑器高度
    max_width = 0.5, -- 最大宽度为50%的编辑器宽度
    min_width = { 0.2, 20 }, -- 最小宽度为20%的编辑器宽度或20列
    win_opts = {
      cursorline = true, -- 显示光标行
      winblend = 10, -- 窗口透明度
    },
    autojump = false, -- 不自动跳转
    preview = false, -- 不显示预览
  },

  -- LSP 配置
  lsp = {
    diagnostics_trigger_update = false, -- 不根据 LSP 诊断更新符号
    update_when_errors = true, -- 在有错误时更新符号
    update_delay = 300, -- 更新延迟为300ms
  },
}

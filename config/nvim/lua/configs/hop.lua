local hop = require "hop"
local directions = require("hop.hint").HintDirection

hop.setup {
  keys = "etovxqpdygfblzhckisuran",
  quit_key = "<ESC>",
  case_insensitive = true,
}

vim.keymap.set("n", "s", function()
  hop.hint_char1 { direction = directions.AFTER_CURSOR }
end, { remap = true })

vim.keymap.set("n", "S", function()
  hop.hint_char1 { direction = directions.BEFORE_CURSOR }
end, { remap = true })

vim.keymap.set("n", "<leader>s", function()
  hop.hint_char2 { direction = directions.AFTER_CURSOR }
end, { remap = true })

vim.keymap.set("n", "<leader>S", function()
  hop.hint_char2 { direction = directions.BEFORE_CURSOR }
end, { remap = true })

vim.keymap.set("n", "f", function()
  hop.hint_char1 { direction = directions.AFTER_CURSOR, current_line_only = true }
end, { remap = true })
vim.keymap.set("n", "F", function()
  hop.hint_char1 { direction = directions.BEFORE_CURSOR, current_line_only = true }
end, { remap = true })
vim.keymap.set("n", "t", function()
  hop.hint_char1 { direction = directions.AFTER_CURSOR, current_line_only = true, hint_offset = -1 }
end, { remap = true })
vim.keymap.set("n", "T", function()
  hop.hint_char1 { direction = directions.BEFORE_CURSOR, current_line_only = true, hint_offset = 1 }
end, { remap = true })

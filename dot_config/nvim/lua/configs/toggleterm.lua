return {
  size = function(term)
    if term.direction == "horizontal" then
      return math.floor(vim.o.lines * 0.3)
    elseif term.direction == "vertical" then
      return math.floor(vim.o.columns * 0.4)
    end
  end,
  open_mapping = "<c-\\>",
  insert_mappings = true,
  start_in_insert = true,
  persist_size = true,
  persist_mode = true,
}

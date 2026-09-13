-- Configure heirline to load on VimEnter so statusline is active on initial startup
---@type LazySpec
return {
  "rebelot/heirline.nvim",
  event = { "VimEnter", "BufEnter" },
}

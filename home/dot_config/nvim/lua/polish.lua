-- Polish: This file is loaded after all plugins and settings are initialized.
-- Ensure XDG state directories for Neovim (undo, swap, backup) exist
local state_dir = vim.fn.stdpath "state"
for _, subdir in ipairs { "undo", "swap", "backup" } do
  local dir = state_dir .. "/" .. subdir
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end


---@type LazySpec
return {
  {
    "alker0/chezmoi.vim",
    specs = {
      {
        "AstroNvim/astrocore",
        opts = function(_, opts)
          local is_windows = vim.fn.has "win32" == 1
          local home = vim.env.HOME or vim.env.USERPROFILE or ""
          local source_dir = is_windows
              and (vim.env.LOCALAPPDATA and (vim.env.LOCALAPPDATA .. "/chezmoi") or (home .. "/AppData/Local/chezmoi"))
            or (home .. "/.local/share/chezmoi")

          opts.options = opts.options or {}
          opts.options.g = opts.options.g or {}
          opts.options.g["chezmoi#source_dir_path"] = source_dir
        end,
      },
    },
  },
  {
    "xvzc/chezmoi.nvim",
    specs = {
      {
        "AstroNvim/astrocore",
        ---@type AstroCoreOpts
        opts = function(_, opts)
          local is_windows = vim.fn.has "win32" == 1
          local home = vim.env.HOME or vim.env.USERPROFILE or ""
          local patterns = {
            home .. "/.local/share/chezmoi/*",
            home .. "/Repos/chezmoi/*",
          }
          if is_windows then
            local localappdata = vim.env.LOCALAPPDATA or (home .. "/AppData/Local")
            table.insert(patterns, localappdata .. "/chezmoi/*")
            table.insert(patterns, home .. "/AppData/Local/chezmoi/*")
          end

          if opts.autocmds and opts.autocmds.chezmoi then
            for _, autocmd in ipairs(opts.autocmds.chezmoi) do
              if autocmd.pattern then
                autocmd.pattern = patterns
              end
            end
          end
        end,
      },
    },
  },
}

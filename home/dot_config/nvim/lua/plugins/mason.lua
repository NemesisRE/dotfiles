-- Customize Mason plugins

---@type LazySpec
return {
  -- use mason-lspconfig to configure LSP installations
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
    end,
  },

  -- Filter out platform-incompatible tools on Windows (e.g. ansible-lint requires Unix)
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    optional = true,
    opts = function(_, opts)
      if vim.fn.has "win32" == 1 and opts.ensure_installed then
        local win_unsupported = { ["ansible-lint"] = true }
        local filtered = {}
        for _, tool in ipairs(opts.ensure_installed) do
          local name = type(tool) == "table" and tool[1] or tool
          if not win_unsupported[name] then
            table.insert(filtered, tool)
          end
        end
        opts.ensure_installed = filtered
      end
    end,
  },
  {
    "jay-babu/mason-null-ls.nvim",
    optional = true,
    opts = function(_, opts)
      if vim.fn.has "win32" == 1 and opts.ensure_installed then
        local win_unsupported = { ["ansible-lint"] = true }
        local filtered = {}
        for _, tool in ipairs(opts.ensure_installed) do
          local name = type(tool) == "table" and tool[1] or tool
          if not win_unsupported[name] then
            table.insert(filtered, tool)
          end
        end
        opts.ensure_installed = filtered
      end
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      if vim.fn.has "win32" == 1 and opts.linters_by_ft then
        opts.linters_by_ft.ansible = nil
      end
    end,
  },
}



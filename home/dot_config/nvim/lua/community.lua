-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

-- Ensure HOME environment variable is set on Windows for cross-platform packs (e.g. chezmoi pack)
if not vim.env.HOME and vim.env.USERPROFILE then
  vim.env.HOME = vim.env.USERPROFILE
end

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.colorscheme.onedarkpro-nvim" },

  -- Language & Tooling Packs
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.docker" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.chezmoi" },
  { import = "astrocommunity.pack.ansible" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.helm" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.ps1" },
  { import = "astrocommunity.pack.terraform" },
}


local M = {}

---@class simpleindent.Config
M.default = {
  filter = {
    filetype = {
      "lspinfo",
      "packer",
      "checkhealth",
      "help",
      "man",
      "gitcommit",
      "dashboard",
      "text",
      "",
    },
    buftype = { "terminal", "quickfix", "nofile", "prompt" },
  },
  symbol = "▏",
}

M.opts = nil ---@type simpleindent.Config?

return M

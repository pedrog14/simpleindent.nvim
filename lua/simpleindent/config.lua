local M = {}

---@class simpleindent.opts
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

M.opts = nil ---@type simpleindent.opts?

return M

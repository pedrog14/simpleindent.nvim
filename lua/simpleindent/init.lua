local M = {}
local config = require("simpleindent.config")
local ns = nil ---@type integer

local filter = function(bufnr)
  local filter = config.opts.filter
  local filetype, buftype = {}, {}

  for _, value in ipairs(filter.filetype) do
    filetype[value] = true
  end

  for _, value in ipairs(filter.buftype) do
    buftype[value] = true
  end

  return filetype[vim.bo[bufnr].filetype] or buftype[vim.bo[bufnr].buftype]
end

---@param _      "win"
---@param winid  integer
---@param bufnr  integer
---@param toprow integer?
---@param botrow integer
local on_win = function(_, winid, bufnr, toprow, botrow)
  if filter(bufnr) then
    return
  end

  local top_row, bot_row = toprow + 1, botrow + 1

  local breakindent = vim.wo[winid].breakindent and vim.wo[winid].wrap
  local changedtick = vim.b[bufnr].changedtick ---@type integer
  local leftcol = vim.api.nvim_win_call(winid, vim.fn.winsaveview).leftcol ---@type integer
  local shiftwidth = vim.bo[bufnr].shiftwidth

  shiftwidth = shiftwidth > 0 and shiftwidth or vim.bo[bufnr].tabstop

  local cache = M.cache[bufnr] ---@type simpleindent.cache
  if not cache or cache.changedtick ~= changedtick then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    ---@class simpleindent.cache
    cache = {
      extmarks = cache and cache.extmarks or {}, ---@type integer[]
      indents = { [0] = 0 }, ---@type integer[]
      changedtick = changedtick,
    }
    M.cache[bufnr] = cache
  end

  local indents = cache.indents
  local extmarks = cache.extmarks

  local space = (vim.wo[winid].listchars or vim.o.listchars):match("space:([^,]*)")
  space = (space and space:sub(1, vim.str_utf_end(space, 1) + 1) or " "):rep(shiftwidth - 1)

  vim.api.nvim_win_call(winid, function()
    for line = top_row, bot_row do
      local indent = indents[line]
      local previous = indent

      if not indent then
        local prev = vim.fn.prevnonblank(line)
        indent = indents[prev] or vim.fn.indent(prev)

        if prev ~= line then
          local next = vim.fn.nextnonblank(line)
          indent = math.max(indent, indents[next] or vim.fn.indent(next))
        end
      end

      if indent ~= previous and indent > leftcol then
        -- stylua: ignore
        local virt_text =
          config.opts.symbol
            :rep(math.ceil(indent / shiftwidth), space)
            :sub(leftcol + 1)

        extmarks[line] = vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
          id = extmarks[line],
          virt_text = { { virt_text, "NonText" } },
          virt_text_pos = "overlay",
          virt_text_repeat_linebreak = breakindent,
          hl_mode = "combine",
          priority = 1,
        })

        indents[line] = indent
      end
    end
  end)
end

---@type simpleindent.cache[]
M.cache = {}

M.setup = function(opts)
  config.opts = vim.tbl_deep_extend("force", config.default, opts or {})
  ns = vim.api.nvim_create_namespace("simpleindent")

  vim.api.nvim_set_decoration_provider(ns, { on_win = on_win })

  local augroup = vim.api.nvim_create_augroup("simpleindent", { clear = true })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = augroup,
    callback = function(args)
      M.cache[args.buf] = nil
    end,
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = augroup,
    pattern = { "shiftwidth", "listchars", "tabstop", "breakindent" },
    callback = vim.schedule_wrap(function()
      for _, winid in ipairs(vim.api.nvim_list_wins()) do
        local bufnr = vim.api.nvim_win_get_buf(winid)
        if M.cache[bufnr] then
          M.cache[bufnr] = nil

          local toprow = vim.fn.line("w0", winid) - 1
          local botrow = vim.fn.line("w$", winid) - 1

          on_win("win", winid, bufnr, toprow, botrow)
        end
      end
    end),
  })
end

return M

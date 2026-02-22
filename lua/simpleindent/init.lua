local M = {}
local config = require("simpleindent.config")
local ns = nil ---@type integer

---@param bufnr integer
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
---@param toprow integer
---@param botrow integer
local on_win = function(_, winid, bufnr, toprow, botrow)
  if filter(bufnr) then
    return
  end

  local top_row, bot_row = toprow + 1, botrow + 1
  local cache = M.cache[bufnr] ---@type simpleindent.cache

  local changedtick = vim.b[bufnr].changedtick ---@type integer

  if not cache or changedtick ~= cache.changedtick then
    ---@class simpleindent.cache
    cache = {
      indents = { [0] = 0 }, ---@type integer[]
      virt_texts = cache and cache.virt_texts or {}, ---@type string[]
      changedtick = changedtick,
    }

    M.cache[bufnr] = cache
  end

  local breakindent = vim.wo[winid].breakindent and vim.wo[winid].wrap
  local leftcol = vim.api.nvim_win_call(winid, vim.fn.winsaveview).leftcol ---@type integer
  local shiftwidth = vim.bo[bufnr].shiftwidth
  shiftwidth = shiftwidth > 0 and shiftwidth or vim.bo[bufnr].tabstop

  local symbol = config.opts.symbol
  local space = (vim.wo[winid].listchars or vim.o.listchars):match("space:([^,]*)") or " "
  local space_rep = space:rep(shiftwidth - 1)

  local indents = cache.indents
  local virt_texts = cache.virt_texts

  vim.api.nvim_win_call(winid, function()
    for line = top_row, bot_row do
      local indent = indents[line]

      if not indent then
        local prev = vim.fn.prevnonblank(line)
        indents[prev] = indents[prev] or vim.fn.indent(prev)
        indent = indents[prev]

        if prev ~= line then
          local next = vim.fn.nextnonblank(line)
          indents[next] = indents[next] or vim.fn.indent(next)
          indent = math.max(indent, indents[next])
        end

        indents[line] = indent
      end

      if indent > leftcol then
        local virt_text = virt_texts[indent]
        if not virt_text then
          virt_text = symbol:rep(math.ceil(indent / shiftwidth), space_rep)
          virt_texts[indent] = virt_text
        end

        if leftcol > 0 then
          local offset = vim.str_byteindex(virt_text, "utf-32", leftcol)
          virt_text = virt_text:sub(offset + 1)
        end

        vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
          virt_text = { { virt_text, "NonText" } },
          virt_text_pos = "overlay",
          virt_text_repeat_linebreak = breakindent,
          virt_text_win_col = 0,
          hl_mode = "combine",
          priority = 1,
          ephemeral = true,
        })
      end
    end
  end)
end

M.cache = nil ---@type simpleindent.cache[]

---@param opts simpleindent.opts?
M.setup = function(opts)
  config.opts = vim.tbl_deep_extend("force", config.default, opts or {})
  ns = vim.api.nvim_create_namespace("simpleindent")
  M.cache = {}

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
      for bufnr, cache in pairs(M.cache) do
        cache.virt_texts = {}
        vim.api.nvim__redraw({ buf = bufnr, flush = false, valid = false })
      end
    end),
  })
end

return M

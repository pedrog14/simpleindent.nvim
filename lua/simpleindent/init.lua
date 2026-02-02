local M = {}
local config = require("simpleindent.config")
local ns = nil ---@type integer

---@param indent integer
---@param data   simpleindent.indents_data
local get_extmarks = function(indent, data)
  local extmarks = M.cache.extmarks
  local key = indent .. ":" .. data.leftcol .. ":" .. data.shiftwidth .. (data.breakindent and ":bi" or "")

  if extmarks[key] then
    return extmarks[key]
  end

  extmarks[key] = {}

  local shiftwidth = data.shiftwidth
  indent = math.ceil(indent / shiftwidth)

  for i = 1, indent do
    local col = (i - 1) * shiftwidth - data.leftcol
    if col >= 0 then
      table.insert(extmarks[key], {
        virt_text = { { config.opts.symbol, "NonText" } },
        virt_text_pos = "overlay",
        virt_text_win_col = col,
        hl_mode = "combine",
        priority = 1,
        ephemeral = true,
        virt_text_repeat_linebreak = data.breakindent,
      })
    end
  end

  return extmarks[key]
end

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

---@param _          "win"
---@param winid      integer Current window id
---@param bufnr      integer Current buffer id
---@param top_row    integer Top window row
---@param bottom_row integer Bottom window row
local on_win = function(_, winid, bufnr, top_row, bottom_row)
  if filter(bufnr) then
    return
  end

  top_row = top_row + 1
  bottom_row = bottom_row + 1

  local indents = M.cache.indents
  local previous, changedtick = indents[winid], vim.b[bufnr].changedtick ---@type simpleindent.indents_data?, integer

  if not (previous and previous.bufnr == bufnr and previous.changedtick == changedtick) then
    previous = nil
  end

  ---@class simpleindent.indents_data
  ---@field indents integer[]
  local data = {
    indents = previous and previous.indents or { [0] = 0 },
    bufnr = bufnr,
    changedtick = changedtick,
    leftcol = vim.api.nvim_buf_call(bufnr, vim.fn.winsaveview).leftcol, ---@type integer
    breakindent = vim.wo[winid].breakindent and vim.wo[winid].wrap,
    shiftwidth = vim.bo[bufnr].shiftwidth,
  }

  data.shiftwidth = data.shiftwidth == 0 and vim.bo[bufnr].tabstop or data.shiftwidth
  indents[winid] = data

  local cur_indents = data.indents

  vim.api.nvim_buf_call(bufnr, function()
    for line = top_row, bottom_row do
      local indent = cur_indents[line]

      if not indent then
        local prev = vim.fn.prevnonblank(line)
        cur_indents[prev] = cur_indents[prev] or vim.fn.indent(prev)
        indent = cur_indents[prev]

        if prev ~= line then
          local next = vim.fn.nextnonblank(line)
          cur_indents[next] = cur_indents[next] or vim.fn.indent(next)
          indent = math.max(indent, cur_indents[next])
        end

        cur_indents[line] = indent
      end

      local extmarks = indent > 0 and get_extmarks(indent, data) or {}

      for _, opts in pairs(extmarks) do
        vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, opts)
      end
    end
  end)
end

M.cache = {}

M.cache.indents = nil ---@type table<integer, simpleindent.indents_data>
M.cache.extmarks = nil ---@type table<string, vim.api.keyset.set_extmark[]>

---@param opts simpleindent.opts?
M.setup = function(opts)
  config.opts = vim.tbl_deep_extend("force", config.default, opts or {})
  ns = vim.api.nvim_create_namespace("SimpleIndent")

  M.cache.indents = {}
  M.cache.extmarks = {}

  local augroup = vim.api.nvim_create_augroup("SimpleIndent", { clear = true })

  vim.api.nvim_set_decoration_provider(ns, { on_win = on_win })

  vim.api.nvim_create_autocmd({ "WinClosed", "BufDelete", "BufWipeout" }, {
    group = augroup,
    callback = function()
      for winid, _ in pairs(M.cache.indents) do
        if not vim.api.nvim_win_is_valid(winid) then
          M.cache.indents[winid] = nil
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = augroup,
    pattern = "shiftwidth",
    callback = vim.schedule_wrap(function()
      for winid, _ in pairs(M.cache.indents) do
        vim.api.nvim__redraw({ win = winid, valid = false, flush = false })
      end
    end),
  })
end

return M

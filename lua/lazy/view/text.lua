local Config = require("lazy.core.config")

---@alias TextSegment {str: string, hl?:string|Extmark}
---@alias Extmark {hl_group?:string, col?:number, end_col?:number}

---@class Text
---@field _lines TextSegment[][]
---@field padding number
local Text = {}

function Text.new()
  local self = setmetatable({}, {
    __index = Text,
  })
  self._lines = {}

  return self
end

---@param str string
---@param hl? string|Extmark
---@param opts? {indent?: number, prefix?: string}
function Text:append(str, hl, opts)
  opts = opts or {}
  if #self._lines == 0 then
    self:nl()
  end

  local lines = vim.split(str, "\n")
  for l, line in ipairs(lines) do
    if opts.prefix then
      line = opts.prefix .. line
    end
    if opts.indent then
      line = string.rep(" ", opts.indent) .. line
    end
    if l > 1 then
      self:nl()
    end
    table.insert(self._lines[#self._lines], {
      str = line,
      hl = hl,
    })
  end

  return self
end

function Text:nl()
  table.insert(self._lines, {})
  return self
end

function Text:render(buf)
  local lines = {}

  for _, line in ipairs(self._lines) do
    local str = (" "):rep(self.padding)

    for _, segment in ipairs(line) do
      str = str .. segment.str
    end

    table.insert(lines, str)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  for l, line in ipairs(self._lines) do
    local col = self.padding

    for _, segment in ipairs(line) do
      local width = vim.fn.strlen(segment.str)

      local extmark = segment.hl
      if extmark then
        if type(extmark) == "string" then
          extmark = { hl_group = extmark, end_col = col + width }
        end
        ---@cast extmark Extmark

        local extmark_col = extmark.col or col
        extmark.col = nil
        vim.api.nvim_buf_set_extmark(buf, Config.ns, l - 1, extmark_col, extmark)
      end

      col = col + width
    end
  end
end

---@param patterns table<string,string>
function Text:highlight(patterns)
  local col = self.padding
  local last = self._lines[#self._lines]
  ---@type TextSegment?
  local text
  for s, segment in ipairs(last) do
    if s == #last then
      text = segment
      break
    end
    col = col + vim.fn.strlen(segment.str)
  end
  if text then
    for pattern, hl in pairs(patterns) do
      local from, to, match = text.str:find(pattern)
      while from do
        if match then
          from, to = text.str:find(match, from, true)
        end
        self:append("", {
          col = col + from - 1,
          end_col = col + to,
          hl_group = hl,
        })
        from, to = text.str:find(pattern, to + 1)
      end
    end
  end
end

function Text:center()
  local last = self._lines[#self._lines]
  if not last then
    return
  end
  local width = 0
  for _, segment in ipairs(last) do
    width = width + vim.fn.strwidth(segment.str)
  end
  width = vim.api.nvim_win_get_width(self.win) - 2 * self.padding - width
  table.insert(last, 1, {
    str = string.rep(" ", math.floor(width / 2 + 0.5)),
  })
  return self
end

function Text:trim()
  -- while #self._lines > 0 and #self._lines[1] == 0 do
  --   table.remove(self._lines, 1)
  -- end

  while #self._lines > 0 and #self._lines[#self._lines] == 0 do
    table.remove(self._lines)
  end
end

function Text:row()
  return #self._lines == 0 and 1 or #self._lines
end

function Text:col()
  if #self._lines == 0 then
    return 0
  end
  local width = 0
  for _, segment in ipairs(self._lines[#self._lines]) do
    width = width + vim.fn.strlen(segment.str)
  end
  return width
end

return Text

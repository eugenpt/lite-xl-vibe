--[[

All things marks.

I think I will make all marks global for now.

]]--

local core = require "core"
local command = require "core.command"
local common = require "core.common"
local keymap = require "core.keymap"
local style = require "core.style"

local misc = require "plugins.lite-xl-vibe.misc"
local kb = require "plugins.lite-xl-vibe.keyboard"

local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end



local marks = {}

marks.global = {}
marks._local = {}

marks.current_abs_filename = ''
marks.current_local = {}  

function marks.set_mark(symbol)
  local line,col = doc():get_selection()
  local abs_filename = doc().abs_filename
  local mark = {
    ["abs_filename"] = abs_filename,
    ["line"] = line,
    ["col"] = col,
    ["line_text"] = doc().lines[line],
    ["symbol"] = symbol,
  }
  if symbol:isUpperCase() then
    -- global
    if marks.global[symbol] == nil then
      marks.global[symbol] = {}
    end
    marks.global[symbol] = mark
  else
    -- local
    if marks._local[abs_filename] == nil then
      marks._local[abs_filename] = {}
    end
    marks._local[abs_filename][symbol] = mark
  end
  -- we know it's current
  marks.current_local[symbol] = mark
end


function marks.update_local(doc)
  local abs_filename = doc.abs_filename
  core.log('marks.update_local %s', abs_filename)
  if marks.current_abs_filename ~= abs_filename then
    
    marks.current_local = {}
    for symbol, mark in pairs(marks.global) do
      marks.current_local[symbol] = mark
    end
    
    if marks._local[abs_filename] then
      for symbol, mark in pairs(marks._local[abs_filename]) do
        marks.current_local[symbol] = mark
      end
    end
    
    marks.current_abs_filename = abs_filename
  end
end

function marks.goto_global_mark(symbol)
  local mark = marks.global[symbol]
  if mark then
    core.log(common.serialize(mark))
    if doc().abs_filename ~= mark.abs_filename then
      core.root_view:open_doc(core.open_doc(mark.abs_filename))
    end
    doc():set_selection(mark.line, mark.col)
  else
    core.vibe.debug_str = 'no mark for '..symbol
  end
end

function marks.goto_local_mark(symbol)
  local mark = marks.current_local[symbol]
  if mark then
    core.root_view:open_doc(core.open_doc(mark.abs_filename))
    doc():set_selection(mark.line, mark.col)
  else
    core.vibe.debug_str = 'no mark for ' .. symbol
  end
end

function marks.translation(symbol, doc) -- line, col are not needed
  local mark = marks.current_local[symbol]
  if mark and mark.abs_filename == doc.abs_filename then
    return mark.line, mark.col
  else
    return nil
  end
end

-------------------------------------------------------------------------------

for c,C in pairs(kb.shift_keys) do
  command.add("core.docview", {
    ['vibe:marks:set-local-'..c] = function()
      marks.set_mark(c)
    end,
    ['vibe:marks:set-global-'..C] = function()
      marks.set_mark(C)
    end,
    ['vibe:marks:go-to-local-'..c] = function()
      marks.goto_local_mark(c)
    end,
    ['vibe:marks:go-to-global-'..C] = function()
      marks.goto_global_mark(C)
    end,
  })
  
  keymap.add_nmap({
    ['m'..c] = 'vibe:marks:set-local-'..c,
    ['m'..C] = 'vibe:marks:set-global-'..C,
    ["'"..c] = 'vibe:marks:go-to-local-'..c,
    ["'"..C] = 'vibe:marks:go-to-global-'..C,
  })
end

-------------------------------------------------------------------------------

function marks.filename()
  return USERDIR .. PATHSEP .. "marks.lua"
end

function marks.load(_filename)
  local filename = _filename or marks.filename()
  local load_f = loadfile(filename)
  local _marks = load_f and load_f()
  if _marks then
    marks.global = _marks.global
    marks._local = _marks._local
  else
    core.error("vibe: Error while loading marks file")
  end  
end

function marks.save(_filename)
  local filename = _filename or marks.filename()
  local fp = io.open(filename, "w")
  if fp then
    local global_text = common.serialize(marks.global)
    local local_text = common.serialize(marks._local)
    fp:write(string.format("return { global = %s, _local = %s }\n",  global_text, local_text))
    fp:close()
  end
end


marks.load()

local on_quit_project = core.on_quit_project
function core.on_quit_project()
  core.try(marks.save)
  on_quit_project()
end


local core__set_active_view = core.set_active_view
function core.set_active_view(view)
  core__set_active_view(view)
  if view.doc and view.doc.abs_filename and marks.update_local then
    marks.update_local(view.doc)
  end
end

command.add(nil, {
  ["vibe: Save Marks"] = marks.save,
  ["vibe: Load Marks"] = marks.load,
})

-------------------------------------------------------------------------------
-- MarksView
-------------------------------------------------------------------------------

local View = require "core.view"

local MarksView = View:extend()

function MarksView:new()
  MarksView.super.new(self)
  self.scrollable = true
  self.brightness = 0
  self:fill_marksview()
end

function MarksView:fill_marksview()
  self.results = {}
  self.last_file_idx = 1
  self.selected_idx = 0
  -- global
  for symbol, mark in pairs(marks.global) do
    table.insert(self.results, { 
      file=core.normalize_to_project_dir(mark.abs_filename) , 
      text=mark.line_text , 
      line=mark.line, 
      col=mark.col, 
      data=mark 
    })
  end
  -- local..
  for filename, markss in pairs(marks._local) do
    for symbol, mark in pairs(markss) do
      table.insert(self.results, {
        file=core.normalize_to_project_dir(mark.abs_filename) ,
        text=mark.line_text , 
        line=mark.line, col=mark.col, data=mark } )
    end
  end
end

function MarksView:get_name()
  return "(book-)Marks List"
end

function MarksView:refresh()
  self:fill_marksview()
end


function MarksView:on_mouse_moved(mx, my, ...)
  MarksView.super.on_mouse_moved(self, mx, my, ...)
  self.selected_idx = 0
  for i, item, x,y,w,h in self:each_visible_result() do
    if mx >= x and my >= y and mx < x + w and my < y + h then
      self.selected_idx = i
      break
    end
  end
end

function MarksView:on_mouse_pressed(...)
  local caught = MarksView.super.on_mouse_pressed(self, ...)
  if not caught then
    self:open_selected_result()
  end
end

function MarksView:open_selected_result()
  local res = self.results[self.selected_idx]
  if not res then
    return
  end
  core.try(function()
    local dv = core.root_view:open_doc(core.open_doc(res.file))
    core.root_view.root_node:update_layout()
    dv.doc:set_selection(res.line, res.col)
    dv:scroll_to_line(res.line, false, true)
  end)
end

function MarksView:update()
  self:move_towards("brightness", 0, 0.1)
  MarksView.super.update(self)
end


function MarksView:get_results_yoffset()
  return style.font:get_height() + style.padding.y * 3
end


function MarksView:get_line_height()
  return style.padding.y + style.font:get_height()
end


function MarksView:get_scrollable_size()
  return self:get_results_yoffset() + #self.results * self:get_line_height()
end


function MarksView:get_visible_results_range()
  local lh = self:get_line_height()
  local oy = self:get_results_yoffset()
  local min = math.max(1, math.floor((self.scroll.y - oy) / lh))
  return min, min + math.floor(self.size.y / lh) + 1
end


function MarksView:each_visible_result()
  return coroutine.wrap(function()
    local lh = self:get_line_height()
    local x, y = self:get_content_offset()
    local min, max = self:get_visible_results_range()
    y = y + self:get_results_yoffset() + lh * (min - 1)
    for i = min, max do
      local item = self.results[i]
      if not item then break end
      coroutine.yield(i, item, x, y, self.size.x, lh)
      y = y + lh
    end
  end)
end


function MarksView:scroll_to_make_selected_visible()
  local h = self:get_line_height()
  local y = self:get_results_yoffset() + h * (self.selected_idx - 1)
  self.scroll.to.y = math.min(self.scroll.to.y, y)
  self.scroll.to.y = math.max(self.scroll.to.y, y + h - self.size.y)
end


function MarksView:draw()
  self:draw_background(style.background)

  -- results
  local y1, y2 = self.position.y, self.position.y + self.size.y
  for i, item, x,y,w,h in self:each_visible_result() do
    local color = style.text
    if i == self.selected_idx then
      color = style.accent
      renderer.draw_rect(x, y, w, h, style.line_highlight)
    end
    x = x + style.padding.x
    local text = string.format("%s at line %d (col %d): ", item.file, item.line, item.col)
    x = common.draw_text(style.font, style.dim, text, "left", x, y, w, h)
    x = common.draw_text(style.code_font, color, item.text, "left", x, y, w, h)
  end

  self:draw_scrollbar()
end

local function fill_marksview()
  local mv = MarksView()
  core.root_view:get_active_node_default():add_view(mv)
end

command.add(nil, {
  ["vibe:marks:show-all"] = fill_marksview,
})

command.add(MarksView, {
  ["vibe:marks:list:select-previous"] = function()
    local view = core.active_view
    view.selected_idx = math.max(view.selected_idx - 1, 1)
    view:scroll_to_make_selected_visible()
  end,

  ["vibe:marks:list:select-next"] = function()
    local view = core.active_view
    view.selected_idx = math.min(view.selected_idx + 1, #view.results)
    view:scroll_to_make_selected_visible()
  end,

  ["vibe:marks:list:open-selected"] = function()
    core.active_view:open_selected_result()
  end,

  ["vibe:marks:list:refresh"] = function()
    core.active_view:refresh()
  end,
  
  ["vibe:marks:list:move-to-previous-page"] = function()
    local view = core.active_view
    view.scroll.to.y = view.scroll.to.y - view.size.y
  end,
  
  ["vibe:marks:list:move-to-next-page"] = function()
    local view = core.active_view
    view.scroll.to.y = view.scroll.to.y + view.size.y
  end,
  
  ["vibe:marks:list:move-to-start-of-doc"] = function()
    local view = core.active_view
    view.scroll.to.y = 0
  end,
  
  ["vibe:marks:list:move-to-end-of-doc"] = function()
    local view = core.active_view
    view.scroll.to.y = view:get_scrollable_size()
  end,
})
-------------------------------------------------------------------------------

keymap.add {
  ["f5"]                 = "vibe:marks:list:refresh",
  ["ctrl+shift+f"]       = "vibe:marks:list:find",
  ["up"]                 = "vibe:marks:list:select-previous",
  ["down"]               = "vibe:marks:list:select-next",
  ["return"]             = "vibe:marks:list:open-selected",
  ["pageup"]             = "vibe:marks:list:move-to-previous-page",
  ["pagedown"]           = "vibe:marks:list:move-to-next-page",
  ["ctrl+home"]          = "vibe:marks:list:move-to-start-of-doc",
  ["ctrl+end"]           = "vibe:marks:list:move-to-end-of-doc",
  ["home"]               = "vibe:marks:list:move-to-start-of-doc",
  ["end"]                = "vibe:marks:list:move-to-end-of-doc"
}

return marks

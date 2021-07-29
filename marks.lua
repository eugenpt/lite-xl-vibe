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

function MarksView:new(text, fn)
  MarksView.super.new(self)
  self.scrollable = true
  self.brightness = 0
  self:begin_search(text, fn)
end


function MarksView:get_name()
  return "(book-)Marks List"
end


local function begin_search(text, fn)
  if text == "" then
    core.error("Expected non-empty string")
    return
  end
  local mv = MarksView(text, fn)
  core.root_view:get_active_node_default():add_view(mv)
end

-------------------------------------------------------------------------------

return marks

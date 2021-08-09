--[[

All things marks.

Type "mx" while in normal mode to make a mark for "x"
Type "'x" or "`x" while in normal mode to go ot a mark for "x"

if x is a lowercase letter - the mark is local to this file
  (you can have marks for one letter in different files)
  (but you will only be able to go to local mark of the current file)
  
if x is an UPPERCASE letter - the mark is global
  (you will go to the mark from any file, opening the file if it is not opened)
  (new mark for the same uppercase letter will owerwrite the previous one)
  
You can list all marks using command "vibe:marks:show-all"


Also you can make named marks using <space><CR>
  
For now all marks are kept between sessions in .config/marks.lua file

]]--

local core = require "core"
local command = require "core.command"
local common = require "core.common"
local keymap = require "core.keymap"
local Doc = require "core.doc"

local misc = require "plugins.lite-xl-vibe.misc"
local kb = require "plugins.lite-xl-vibe.keyboard"
local ResultsView = require "plugins.lite-xl-vibe.ResultsView"

local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end


local marks = {}

marks.global = {}
marks._local = {}


function marks.set_mark(symbol, global_flag)
  local line,col = doc():get_selection()
  local abs_filename = doc().abs_filename
  local mark = {
    ["abs_filename"] = abs_filename,
    ["line"] = line,
    ["col"] = col,
    ["line_text"] = doc().lines[line],
    ["symbol"] = symbol,
  }
  if global_flag or symbol:isUpperCase() then
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
  local mark = marks._local[doc().abs_filename] and marks._local[doc().abs_filename][symbol]
  if mark then
    core.root_view:open_doc(core.open_doc(mark.abs_filename))
    doc():set_selection(mark.line, mark.col)
  else
    core.vibe.debug_str = 'no mark for ' .. symbol
  end
end

function marks.translation(symbol, doc) -- line, col are not needed
  local mark = marks.global[symbol]
               or (marks._local[doc.abs_filename]
                   and marks._local[doc.abs_filename][symbol])
  if mark and mark.abs_filename == doc.abs_filename then
    -- pass?
  else
    marks.goto_global_mark(symbol)
  end
  return mark.line, mark.col
end

function marks.translation_fun(symbol)
  return function(doc)
           return marks.translation(symbol, doc)
         end
end

function marks.have_global_mark_fun(symbol)
  return function() return marks.global[symbol] end
end

function marks.have_local_mark_fun(symbol)
  return function()
    return doc() and (
          (
          marks._local[doc().abs_filename] 
          and marks._local[doc().abs_filename][symbol]
          ) or (
          marks.global[symbol]
          and marks.global[symbol].abs_filename==doc().abs_filename
          and marks.global[symbol]
          )
        )
  end
end

-------------------------------------------------------------------------------
-- commands and keymaps for one-symbol marks

local function commands_from_tranlations(translations, no_select, no_move)
  local commands = {}
  
  for name, fn in pairs(translations) do
    if not no_move then
      commands["doc:move-to-" .. name] = function() doc():move_to(fn, dv()) end
    end
    if not no_select then
      commands["doc:select-to-" .. name] = function() doc():select_to(fn, dv()) end
      commands["doc:delete-to-" .. name] = function() doc():delete_to(fn, dv()) end
    end
  end

  return commands
end

for _,c in ipairs(kb.letters) do
  local C = c:upper()
command.add("core.docview", {
    ['vibe:marks:set-local-'..c] = function()
      marks.set_mark(c)
    end,
    ['vibe:marks:set-global-'..C] = function()
      marks.set_mark(C)
    end,
  })
  
  command.add( marks.have_local_mark_fun(c), 
               commands_from_tranlations({['local-'..c] = marks.translation_fun(c)}))
    
  local translations = {['global-'..C] = marks.translation_fun(C)}
  command.add( marks.have_global_mark_fun(C), 
               commands_from_tranlations(translations, true))
  -- but selects only go to locally defined marks!
  command.add( marks.have_local_mark_fun(C), 
               commands_from_tranlations(translations, false, true))
               
  
  keymap.add_nmap({
    ['m'..c] = 'vibe:marks:set-local-'..c,
    ['m'..C] = 'vibe:marks:set-global-'..C,
    ["'"..c] = 'doc:move-to-local-'..c,
    ["`"..c] = 'doc:move-to-local-'..c,
    ["'"..C] = 'doc:move-to-global-'..C,
    ["`"..C] = 'doc:move-to-global-'..C,
  })
end



-------------------------------------------------------------------------------
-- Shift marks' line numbers on doc edits
-------------------------------------------------------------------------------
-- -- based on lite-xl/lite-plugins/master/plugins/markers.lua
-------------------------------------------------------------------------------
local function shift_mark(mark, at, diff)
  mark['line'] = mark['line'] >= at and mark['line'] + diff or mark['line']
end

local function shift_lines(doc, at, diff)
  if diff == 0 then return end
  for _, mark in pairs(marks.global) do
    if mark.abs_filename == doc.abs_filename then
      shift_mark(mark, at, diff)
    end
  end  
  if marks._local[doc.abs_filename] then
    for _, mark in pairs(marks._local[doc.abs_filename]) do
      shift_mark(mark, at, diff)
    end
  end
end


local raw_insert = Doc.raw_insert

function Doc:raw_insert(line, col, text, ...)
  raw_insert(self, line, col, text, ...)
  local line_count = 0
  for _ in text:gmatch("\n") do
    line_count = line_count + 1
  end
  shift_lines(self, line, line_count)
end


local raw_remove = Doc.raw_remove

function Doc:raw_remove(line1, col1, line2, col2, ...)
  raw_remove(self, line1, col1, line2, col2, ...)
  shift_lines(self, line2, line1 - line2)
end

-------------------------------------------------------------------------------
-- DOOM Emacs kind of marks
command.add("core.docview", {
  ['vibe:marks:create-or-move-to-named-mark'] = function()
    -- If you want, you could use doom's default bookmark name.. I won't
    -- core.command_view:set_text(doc().filename)
    local doc_filename = doc().abs_filename
    if misc.has_selection() then
      core.command_view:set_text(doc():get_text(doc():get_selection()))
    end
    core.command_view:enter("Create or go to mark", function(text, item)
      if item then
        if item.global then
          marks.goto_global_mark(item.symbol)
        else
          marks.goto_local_mark(item.symbol)
        end
      else 
        marks.set_mark(text, true)
      end
    end, function(text)
      local items = {}
      for symbol,mark in pairs(marks.global) do
        table.insert(items, {
          ["text"]   = symbol..'| '..mark.abs_filename..' | '..mark.line_text,
          ["symbol"] = symbol,
          ["global"] = true,
        })
      end
      for symbol, mark in pairs(marks._local[doc_filename] or {}) do
        table.insert(items, {
          ["text"]   = symbol..'| '..mark.abs_filename..' | '..mark.line_text,
          ["symbol"] = symbol,
        })
      end
      return misc.fuzzy_match_key(items, 'text', text)
    end)
  end,
})

-- and proper DOOM Emacs keymap
keymap.add_nmap({
  ['<space><CR>'] = 'vibe:marks:create-or-move-to-named-mark',
})

-------------------------------------------------------------------------------
-- Save / Load
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


command.add(nil, {
  ["vibe: Save Marks"] = marks.save,
  ["vibe: Load Marks"] = marks.load,
})

-------------------------------------------------------------------------------
-- MarksView
-------------------------------------------------------------------------------


local function fill_results()
  local mv = ResultsView("(book-)Marks List",function()
    local items = {}
    -- global
    for symbol, mark in pairs(marks.global) do
      table.insert(items, { 
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
        table.insert(items, {
          file=core.normalize_to_project_dir(mark.abs_filename) ,
          text=mark.line_text , 
          line=mark.line, col=mark.col, data=mark } )
      end
    end
    -- title: symbol and position
    for _,item in ipairs(items) do
      item.title = string.format("[%s] %s at line %d (col %d): ",
                                item.data.symbol, item.file, item.line, item.col)
    end                             
    core.log('items_fun : %i items',#items)
    return items
  end, function(res)
    local dv = core.root_view:open_doc(core.open_doc(res.file))
    core.root_view.root_node:update_layout()
    dv.doc:set_selection(res.line, res.col)
    dv:scroll_to_line(res.line, false, true)
  end)
  core.root_view:get_active_node_default():add_view(mv)
end

command.add(nil, {
  ["vibe:marks:show-all"] = fill_results,
  ["vibe:marks:clear-all"] = function()
    marks.global = {}
    marks._local = {}
  end,
})

return marks

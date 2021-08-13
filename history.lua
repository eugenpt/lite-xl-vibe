--[[
.
Global location history
.
I don't know yet if I will track line numbers changes on file edits or not
.
(dots are for paragraph navigation)
.
]]--

local core = require "core"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local DocView = require "core.docview"
local Doc = require "core.doc"
local CommandView = require "core.commandview"
local style = require "core.style"
local config = require "core.config"
local common = require "core.common"
local translate = require "core.doc.translate"

local kb = require "plugins.lite-xl-vibe.keyboard"
local misc = require "plugins.lite-xl-vibe.misc"
local ResultsView = require "plugins.lite-xl-vibe.ResultsView"

local history = {}

history.marks = {}
history.marks_max = 0 -- a boundary, for ading new and moving forward
history.marks_ix = 0  -- for going back/forth
history.last_event_time = 0


local function mark_text(mark)
  return string.format("[%i] % 3i:% 2i",mark.j, mark.line, mark.col)
                       ..'| '..mark.abs_filename..' | '..mark.line_text
end

function history.push_mark()
  if core.active_view and core.active_view.doc 
     and core.active_view.doc.abs_filename then
    local doc = core.active_view.doc
    local line, col = doc:get_selection()
    
    local mark = history.marks[history.marks_ix]
    
    if mark and mark.abs_filename == doc.abs_filename
       and (math.abs(mark.line - line)<=config.vibe.history_max_dline_to_join
            or (system.get_time() - history.last_event_time <= config.vibe.history_max_dt_to_join))
         then
      -- simply update the `current` history item
      mark.line = line
      mark.col = col
      mark.line_text = doc.lines[line]
      mark.text = mark_text(mark)
    else
      history.marks_max = history.marks_max + 1
      history.marks_ix = history.marks_max
      history.marks[history.marks_max] = {
        line = line,
        col = col,
        abs_filename = doc.abs_filename,
        line_text = doc.lines[line],
      }
      history.marks[history.marks_max].j=history.marks_ix
      
      history.marks[history.marks_max].text = mark_text(history.marks[history.marks_max])
    end
    history.last_event_time = system.get_time()
  end
end

history.doc__set_selection__orig = Doc.set_selection
function Doc:set_selection(...)
  history.doc__set_selection__orig(self, ...)
  history.push_mark()  
end

function history.goto_mark(mark)
  if core.active_view
     and core.active_view.doc 
     and core.active_view.doc.abs_filename==mark.abs_filename 
  then
    -- pass, we are here
  else
    core.root_view:open_doc(core.open_doc(mark.abs_filename))
  end
  history.marks_ix = mark.j
  core.active_view.doc:set_selection(mark.line, mark.col)
end


command.add(nil, {
  ["vibe:history:move-back"] = function()
    history.marks_ix = history.marks_ix - 1
    if history.marks_ix <= 0 then
      history.marks_ix = history.marks_max
    end
    local mark = history.marks[history.marks_ix]
    if mark then
      history.goto_mark(mark)
    end
  end,
  
  ["vibe:history:move-forward"] = function()
    history.marks_ix = history.marks_ix + 1
    if history.marks_ix > history.marks_max then
      history.marks_ix = 1
    end
    local mark = history.marks[history.marks_ix]
    if mark then
      history.goto_mark(mark)
    end
  end,
  
  ["vibe:history:list-all"] = function()
    local mv = ResultsView("Jumplist",function()
      local items = {}
      -- global
      for j,mark in ipairs(history.marks) do
        table.insert(items, { 
          file=core.normalize_to_project_dir(mark.abs_filename) , 
          text=mark.line_text , 
          line=mark.line, 
          col=mark.col, 
          j = j,
          data=mark 
        })
      end
      -- title: symbol and position
      for _,item in ipairs(items) do
        item.title = string.format("[%s] %s at line %d (col %d): ",
                                  item.j, item.file, item.line, item.col)
      end                             
      core.log('items_fun : %i items',#items)
      return items
    end, function(res)
      command.perform("root:close")
      local dv = core.root_view:open_doc(core.open_doc(res.file))
      core.root_view.root_node:update_layout()
      dv.doc:set_selection(res.line, res.col)
      dv:scroll_to_line(res.line, false, true)
    end)
    if history.marks_ix and history.marks[history.marks_ix] then
        mv.selected_idx = history.marks_ix
    end
    core.root_view:get_active_node_default():add_view(mv)
  end,
  
  ["vibe:history:search"] = function()
    core.command_view:enter("Search history(jumplist):", function(text, item)
      history.goto_mark(item)
    end, function(text)
      return misc.literal_match_key(history.marks, 'text', text)
    end)
  end,

  ["vibe:history:fuzzy-search"] = function()
    core.command_view:enter("Search history(jumplist):", function(text, item)
      history.goto_mark(item)
    end, function(text)
      return misc.fuzzy_match_key(history.marks, 'text', text)
    end)
  end,
})




return history

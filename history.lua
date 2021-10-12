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
     and (core.active_view.doc.abs_filename or core.active_view.doc.filename) then
    local doc = core.active_view.doc
    local line, col = doc:get_selection()
    
    local current_mark = {
        line = line,
        col = col,
        abs_filename = doc.abs_filename or doc.filename,
        line_text = doc.lines[line],
        line_items = core.active_view:get_line_draw_items(line),
        time = 1*os.time(),
    }
    
    local mark = history.marks[history.marks_ix]
    
    if mark and mark.abs_filename == (doc.abs_filename or doc.filename)
       and (math.abs(mark.line - line)<=config.vibe.history_max_dline_to_join
            or (system.get_time() - history.last_event_time <= config.vibe.history_max_dt_to_join))
         then
      -- pass, update the current below
    else
      -- create new
      history.marks_max = history.marks_max + 1
      history.marks_ix = history.marks_max
    end
    history.marks[history.marks_ix] = {
      line = line,
      col = col,
      abs_filename = doc.abs_filename or doc.filename,
      line_text = doc.lines[line],
      line_items = core.active_view:get_line_draw_items(line),
      time = 1*os.time(),
    }
    history.marks[history.marks_ix].j=history.marks_ix
    
    history.marks[history.marks_ix].text = mark_text(history.marks[history.marks_max])
    history.last_event_time = system.get_time()
  end
end

history.doc__set_selection__orig = Doc.set_selection
function Doc:set_selection(...)
  history.doc__set_selection__orig(self, ...)
  history.push_mark()  
end
history.doc__set_selections__orig = Doc.set_selections
function Doc:set_selections(idx, ...)
  history.doc__set_selections__orig(self, idx, ...)
  if idx==1 then
    history.push_mark()  
  end
end

function history.goto_mark(mark)
  misc.goto_mark(mark)
  history.marks_ix = mark.j
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
    local mv = ResultsView.new_and_add({
      title="Jumplist",
      items_fun=function()
        local items = table.map_with_ix(
          history.marks, 
          function(j, mark)
            return { 
              file=core.normalize_to_project_dir(mark.abs_filename) , 
              Text=mark.line_items or mark.line_text , 
              line=mark.line, 
              col=mark.col, 
              j = j,
              data=mark,
              N = misc.str(j),
              Line=misc.str(mark.line),
              Date=os.date("%Y-%m-%d %X %a", mark.time),
            }
          end
        )
        for _,item in ipairs(items) do
          item.search_text = string.format("[%s] %s %s at line %d (col %d): %s",
            item.j, item.Date, item.File, item.line, item.col, item.data.line_text)
          item.File = misc.path_shorten(item.file)
        end                             
        core.log('items_fun : %i items',#items)
        return items
      end, 
      on_click_fun=function(res)
        command.perform("root:close")
        local dv = core.root_view:open_doc(core.open_doc(res.file))
        core.root_view.root_node:update_layout()
        dv.doc:set_selection(res.line, res.col)
        dv:scroll_to_line(res.line, false, true)
      end,
      column_names={'N','Date','File','Text'}
    })
    if history.marks_ix and history.marks[history.marks_ix] then
        mv.selected_idx = history.marks_ix
    end
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

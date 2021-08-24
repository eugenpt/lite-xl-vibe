
local core = require "core"
local command = require "core.command"
local common = require "core.common"
local keymap = require "core.keymap"
local style = require "core.style"
local translate = require "core.doc.translate"

local misc = require "plugins.lite-xl-vibe.misc"
local ResultsView = require "plugins.lite-xl-vibe.ResultsView"

local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end

local function is_mode(mode)
  return function() return core.vibe.mode==mode end
end


local com = {}

com.caret_width__orig = style.caret_width

command.add(nil, {
  ["vibe:switch-to-insert-mode"] = function()
    core.vibe.mode = "insert"
  end,
  ["vibe:switch-to-normal-mode"] = function()
    core.vibe.mode = "normal"
  end,
  ["vibe:escape"] = function()
    if misc.has_selection() then
      misc.drop_selection()
    else
      core.vibe.reset_seq()
    end
    if core.active_view:is(ResultsView) then
      command.perform("vibe:results:drop-search")
    end
  end,
  ["vibe:run-strokes"] = function()
    core.command_view:enter("Strokes to run:", function(text)
      core.vibe.run_stroke_seq(text)
    end)
  end,

  ["vibe:repeat"] = function()
    -- I was deleting the last stroke seq here
    --  (the one activating this repeat command)
    -- but that's wrong 
    --  (for one I could in theory run it via CommandView)
    --   so I moved the deletion to vibe.process_stroke
    core.log('vibe:repeat seq=|%s|', core.vibe.last_executed_seq)
    core.vibe.run_stroke_seq(core.vibe.last_executed_seq)
  end,

  ["vibe:repeat-find-in-line"] = function()
    if core.vibe.last_line_find == nil then
      core.vibe.debug_str = 'no last line search..'
      return
    end
    doc():move_to(function(doc,line,col)
      return misc.find_in_line(
        core.vibe.last_line_find["symbol"], 
        core.vibe.last_line_find["backwards"],
        core.vibe.last_line_find["include"],
        doc, line, col
      )
    end, dv())
  end,
  
  ["vibe:rotate-clipboard-ring"] = function()
    misc.clipboard_ring_rotate()
  end,
  
  ["vibe:open-scratch-buffer"] = function()
    core.root_view:open_doc(core.open_doc(misc.scratch_filepath()))
  end,
  
  ["vibe:switch-to-last-tab"] = function()
    local node = core.root_view:get_active_node()
    node:set_active_view(core.last_active_view)
  end,
  
  ["vibe:paste"] = function()
    core.log('vibe:paste')
    local text
    if core.vibe.target_register
       and core.vibe.registers[core.vibe.target_register] then
      system.set_clipboard(core.vibe.registers[core.vibe.target_register], true)
      -- aand zero it back for further actions
      core.vibe.target_register = nil
    end
    if doc():has_selection() then
      text = doc():get_text(doc():get_selection())
    end
    command.perform("doc:paste")
    if text then
      system.set_clipboard(text)
    end
  end,
  
  ["vibe:delete-symbol-under-cursor"] = function()
      local doc = core.active_view and core.active_view.doc
      if doc then
        local line,col,line2,col2 = doc:get_selection()
        doc:set_selection(line,col)
        doc:delete_to(translate.next_char)
        doc:set_selection(line,col,line2,col2)
      end
  end,
})


command.add(misc.has_selection, {
  ["vibe:copy"] = function()
    core.log('vibe:copy')
    command.perform("doc:copy")
    if core.vibe.target_register then
      core.vibe.registers[core.vibe.target_register] = system.get_clipboard()
      core.vibe.debug_str = "copied to "..core.vibe.target_register
      -- aand zero it back for further actions
      core.vibe.target_register = nil
    else
      core.vibe.debug_str = "copied"
    end
    misc.drop_selection()
  end,
  ["vibe:delete"] = function()
    core.log('vibe:delete')
    local text = doc():get_text(doc():get_selection())
    if core.vibe.target_register then
      core.vibe.registers[core.vibe.target_register] = text
      -- aand zero it back for further actions
      core.vibe.target_register = nil
    end
    system.set_clipboard(text)
    command.perform("doc:delete")
  end,
  ["vibe:change"] = function()
    command.perform("vibe:delete")
    command.perform("vibe:switch-to-insert-mode")
  end,
  ["vibe:indent"] = function()
    command.perform("doc:indent")
  end,
  ["vibe:unindent"] = function()
    command.perform("doc:unindent")
  end,
})

command.add(nil, {
  ["vibe:switch-to-tab-search"] = function()
    core.command_view:enter("Switch to tab:", function(text, item)
      if item then
        core.root_view:open_doc(item.doc)
      else 
        local filename = system.absolute_path(common.home_expand(text))
        core.root_view:open_doc(core.open_doc(filename))
      end
    end, function(text)
      local items = {}
      for _, doc in ipairs(core.docs) do
        table.insert(items, {
          ["text"]   = doc.abs_filename,
          ["doc"] = doc,
        })
      end
      return misc.fuzzy_match_key(items, 'text', text)
    end)
  end,

  ["vibe:tabs-list"] = function()
    if core.vibe.tabs_list_view then
      core.vibe.tabs_list_view:refresh()
      local node = core.root_view:get_active_node()
      node:set_active_view(core.vibe.tabs_list_view)
    else
      local mv = ResultsView("Opened Files", misc.get_tabs_list, function(res)
        local dv = core.root_view:open_doc(res.doc)
      end)
      core.vibe.tabs_list_view = mv
      core.root_view:get_active_node_default():add_view(core.vibe.tabs_list_view)
    end
  end,
})

command.add("core.docview", {
  ["vibe:move-to-start-of-doc"] = function()
    if core.vibe.num_arg == '' then
      command.perform("doc:move-to-start-of-doc")
    else
      misc.move_to_line(tonumber(core.vibe.num_arg))
    end
  end,
  ["vibe:move-to-end-of-doc"] = function()
    if core.vibe.num_arg == '' then
      command.perform("doc:move-to-end-of-doc")
    else
      misc.move_to_line(tonumber(core.vibe.num_arg))
    end
  end,
})

-- can't put this into misc since ResultsView depends on misc
command.add(nil, {
  ["core:exec-history"] = function()
    local mv = ResultsView("Execution History",function()
      local items = {}
      for _,item in ipairs(misc.exec_history) do
        table.insert(items, { text=item })
      end                             
      core.log('items_fun : %i items',#items)
      return items
    end, function(res)
      misc.exec_text = res.text
      command.perform('root:close')
      command.perform("core:exec-input")
    end)
    core.root_view:get_active_node_default():add_view(mv)
  end,
})

return com

--[[

  Registers and macros

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
local ResultsView = require "plugins.lite-xl-vibe.ResultsView"

local registers = {}


local function start_recording_macro(symbol)
  registers[symbol] = ''
  core.vibe.recording_register = symbol
  core.vibe.flags['recording_macro'] = true
end

local function stop_recording_macro(symbol)
  core.vibe.recording_register = nil
  core.vibe.flags['recording_macro'] = false
end

for _,symbol in ipairs(kb.all_typed_symbols) do

command.add(nil, {
  ["vibe:target-register-"..symbol] = function()
    core.log("vibe:target-register-"..symbol)
    core.vibe.target_register = symbol
  end,
})

command.add(function() return not core.vibe.flags['recording_macro'] end,{
  ["vibe:macro:start-recording-"..symbol] = function()
    start_recording_macro(symbol) 
  end,
  ["vibe:macro:play-macro-"..symbol] = function()
    core.log_quiet('play macro for %s = |%s|', symbol, registers[symbol])
    core.vibe.reset_seq()
    core.vibe.run_stroke_seq(registers[symbol])
  end,
})
end

command.add(function() return core.vibe.flags['recording_macro'] end,{
  ["vibe:macro:stop-recording"] = function()
    -- remove the q
    -- -- TODO: write a proper thing here..
    registers[core.vibe.recording_register] = 
      registers[core.vibe.recording_register]:sub(1,
        #registers[core.vibe.recording_register] - 1)
    --
    core.vibe.recording_register = nil
    core.vibe.flags['recording_macro'] = false
  end,
})

command.add(nil, {
  ["vibe:registers-macro:list-all"] = function()
    local mv = ResultsView("Registers List", function()
      local items = {}
      -- registers
      for reg, text in pairs(registers) do
        if text then
          table.insert(items, {
            ["title"] = '<'..reg..'>',
            ["text"] = text,
          })
        end
      end
      -- clipboard ring
      for ix,item in pairs(core.vibe.clipboard_ring) do
        if item then
          table.insert(items, {
            ["title"] = '<clipboard-'..tostring(ix)..'>',
            ["text"] = item,
          })
        end
      end
      return items
    end, function(res)
      system.set_clipboard(res.text, true) -- true for skip the ring
      command.perform('root:close')
    end)
    core.root_view:get_active_node_default():add_view(mv)
  end,
})

return registers

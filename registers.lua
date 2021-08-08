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
local misc = require "plugins.lite-xl-vibe.misc"
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

local function register_fuzzy_sort(opts)
  return function(text)
  local items = {}
  for symbol,register in pairs(registers) do
    table.insert(items, {
      ["text"]   = symbol..'| '..register,
      ["content"] = register,
      ["symbol"] = symbol,
    })
  end
  if opts['add_ring'] then
  for i, register in pairs(core.vibe.clipboard_ring) do
    table.insert(items, {
      ["text"]   = '<'..tonumber(i)..'>'..'| '..register,
      ["content"] = register,
    })
  end
  end
  return misc.fuzzy_match_key(items, 'text', text)
  end
end

command.add("core.docview", {
  ["vibe:registers:search-and-paste"] = function()
    core.command_view:enter("Insert from register (clipboard)", function(text, item)
      if item then
        system.set_clipboard(item.content, true) -- true for skip ring
        command.perform("vibe:paste")
      else 
        -- like.. ??
      end
    end, register_fuzzy_sort({add_ring=true}))
  end,
})
command.add(misc.has_selection, {
  ["vibe:registers:search-and-copy"] = function()
    core.command_view:enter("Copy to register (clipboard)", function(text, item)
      if item then
        core.vibe.target_register = item.symbol
      else 
        core.vibe.target_register = text
      end
      command.perform("vibe:copy")
    end, register_fuzzy_sort({add_ring=false}))
  end,
})

-------------------------------------------------------------------------------
-- Save / Load
-------------------------------------------------------------------------------

local function registers_filename()
  return USERDIR .. PATHSEP .. "registers.lua"
end

local function registers_load(_filename)
  local filename = _filename or registers_filename()
  local load_f = loadfile(filename)
  local _registers = load_f and load_f()
  if _registers and _registers.clipboard_ring then
    registers= _registers.registers
    core.vibe.clipboard_ring = _registers.clipboard_ring
    core.vibe.clipboard_ring_ix = #_registers.clipboard_ring
    system.set_clipboard(core.vibe.clipboard_ring[#_registers.clipboard_ring], true)
  else
    core.error("vibe: Error while loading registers file")
  end  
end

local function registers_save(_filename)
  local filename = _filename or registers_filename()
  local fp = io.open(filename, "w")
  if fp then
    local regs = common.serialize(registers)
    local ring = common.serialize(core.vibe.clipboard_ring)
    fp:write(string.format("return { registers=%s , clipboard_ring=%s}\n", regs, ring))
    fp:close()
  end
end

registers_load()

local on_quit_project = core.on_quit_project
function core.on_quit_project()
  core.try(registers_save)
  on_quit_project()
end


command.add(nil, {
  ["vibe:save-registers"] = registers_save,
  ["vibe:load-registers"] = registers_load,
})

return registers

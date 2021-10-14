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
    core.log_quiet('play macro for %s = |%s|', symbol, core.vibe.registers[symbol])
    core.vibe.reset_seq()
    core.vibe.run_stroke_seq(core.vibe.registers[symbol])
  end,
})
end

command.add(function() return core.vibe.flags['recording_macro'] end,{
  ["vibe:macro:stop-recording"] = function()
    -- remove the q
    -- -- TODO: write a proper thing here..
    core.vibe.registers[core.vibe.recording_register] =
      core.vibe.registers[core.vibe.recording_register]:sub(1,
        #core.vibe.registers[core.vibe.recording_register] - 1)
    --
    core.vibe.recording_register = nil
    core.vibe.flags['recording_macro'] = false
  end,
})

command.add(nil, {
  ["vibe:registers-macro:list-all"] = function()
    ResultsView.new_and_add({
      title="Registers List", 
      items_fun=function()
        local items = {}
        -- registers
        for reg, text in pairs(core.vibe.registers) do
          if text then
            table.insert(items, {
              ["title"] = '<'..reg..'>',
              ["text"] = misc.gsub_newline(text),
            })
          end
        end
        -- clipboard ring
        for ix,item in pairs(core.vibe.clipboard_ring) do
          if item then
            table.insert(items, {
              ["title"] = '<clipboard-'..tostring(ix)..'>',
              ["text"] = misc.gsub_newline(item),
            })
          end
        end
        return items
      end, 
      on_click_fun=function(res)
        system.set_clipboard(res.text, true) -- true for skip the ring
        command.perform('root:close')
      end
    })
  end,
})

local function register_fuzzy_sort(opts)
  return function(text)
  local items = {}
  for symbol,register in pairs(core.vibe.registers) do
    table.insert(items, {
      ["text"]   = symbol..'| '..misc.gsub_newline(register),
      ["content"] = register,
      ["symbol"] = symbol,
    })
  end
  if opts['add_ring'] then
    for i, register in pairs(core.vibe.clipboard_ring) do
      table.insert(items, {
        ["text"]   = '<'..tonumber(i)..'>'..'| '..misc.gsub_newline(register),
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
      -- this might confuse some people,
      --  the register selected may be matched by the input text
      --    and not by the highlighted line in the CommandView
      local s = core.vibe.registers[text]
      if misc.command_match_sug(text, item) then
        s = item.content
      else
        core.log("text~=item")
        core.log("%s ~= %s", text, item.text)
      end
      if s then
        system.set_clipboard(s, true) -- true for skip ring
        command.perform("vibe:paste")
      else
        -- like.. ??
        core.error("No record for [%s]", text)
      end
    end, register_fuzzy_sort({add_ring=true}))
  end,
})

command.add(misc.has_selection, {
  ["vibe:registers:search-and-copy"] = function()
    core.command_view:enter("Copy to register (clipboard)", function(text, item)
      if misc.command_match_sug(text, item) then
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
  return misc.USERDIR .. PATHSEP .. "registers.lua"
end

local function registers_load(_filename)
  local filename = _filename or registers_filename()
  local load_f = loadfile(filename)
  local _registers = load_f and load_f()
  if _registers and _registers.clipboard_ring then
    core.vibe.registers= _registers.registers
    core.vibe.clipboard_ring = _registers.clipboard_ring
    core.vibe.clipboard_ring_max = 0
    for j,_ in pairs(core.vibe.clipboard_ring) do
      if j > core.vibe.clipboard_ring_max then
        core.vibe.clipboard_ring_max = j
      end
    end
    core.vibe.clipboard_ring_ix = core.vibe.clipboard_ring_max
    system.set_clipboard(core.vibe.clipboard_ring[core.vibe.clipboard_ring_max], true)
  else
    core.error("vibe: Error while loading registers file")
  end
end

local function registers_save(_filename)
  local filename = _filename or registers_filename()
  local fp = io.open(filename, "w")
  if fp then
    local regs = common.serialize(core.vibe.registers)
    local ring = common.serialize(core.vibe.clipboard_ring)
    fp:write(string.format("return { registers=%s , clipboard_ring=%s}\n", regs, ring))
    fp:close()
  end
end

-- -- those are handled by vibe workspace
-- registers_load()
-- local on_quit_project = core.on_quit_project
-- function core.on_quit_project()
--   core.try(registers_save)
--   on_quit_project()
-- end

local function registers_clear()
  core.vibe.registers = {}
  core.vibe.clipboard_ring = {}
  core.vibe.clipboard_ring_ix = 0
  core.vibe.clipboard_ring_max = 0
end


command.add(nil, {
  ["vibe:save-registers"] = registers_save,
  ["vibe:load-registers"] = registers_load,
  ["vibe:clear-registers"] = registers_clear,
})

return registers

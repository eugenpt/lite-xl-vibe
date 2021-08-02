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
    core.vibe.recording_register = nil
    core.vibe.flags['recording_macro'] = false
  end,
})

return registers

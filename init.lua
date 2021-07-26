-- mod-version:1 -- lite-xl 1.16
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local DocView = require "core.docview"
local CommandView = require "core.commandview"


local misc = require "plugins.lite-xl-vibe.misc"




local vibe = {}
core.vibe = vibe

vibe.kb = require "plugins.lite-xl-vibe.keyboard"
vibe.mode = 'insert'

vibe.debug_str = 'test debug_str'
vibe.last_stroke = ''

vibe.com = require "plugins.lite-xl-vibe.com"

require "plugins.lite-xl-vibe.keymap"

vibe.interface = require "plugins.lite-xl-vibe.interface"




-- yeah, this is a test
core.error(vibe.mode:isUpperCase() and "true" or "false")


local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end


vibe.on_key_pressed__orig = keymap.on_key_pressed
function keymap.on_key_pressed(k)
  if dv():is(CommandView) then
    -- only original lite-xl mode in CommandViews
    -- .. for now at least
    return vibe.on_key_pressed__orig(k)
  end

  -- I need the finer control on this (I think..)
  local mk = vibe.kb.modkey_map[k]
  if mk then
    vibe.last_stroke = k
    keymap.modkeys[mk] = true
    -- work-around for windows where `altgr` is treated as `ctrl+alt`
    if mk == "altgr" then
      keymap.modkeys["ctrl"] = false
    end
  else
    -- first - current stroke
    vibe.last_stroke = vibe.kb.key_to_stroke(k)
    
    local stroke__orig = vibe.kb.key_to_stroke__orig(k)
    local commands = {}
    
    if vibe.mode == "insert" then
      commands = keymap.map[stroke__orig]
    elseif vibe.mode == "normal" then
      commands = keymap.nmap[vibe.last_stroke]
    end
    
    if commands then
      for _, cmd in ipairs(commands) do
        local performed = command.perform(cmd)
        if performed then break end
      end
      return true
    end    
    
    if vibe.mode=='insert' then
      return false
    else
      return true -- no text input in normal mode
    end
  end
  return false
end


function vibe:get_mode_str()
  return self and (self.mode == 'insert' and "INSERT" or "NORMAL") or 'nil?'
end


core.log("lite-xl-vibe loaded.")
return vibe

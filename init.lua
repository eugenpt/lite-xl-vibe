-- mod-version:1 -- lite-xl 1.16
local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local DocView = require "core.docview"
local CommandView = require "core.commandview"
local StatusView = require "core.statusview"

local misc = require "plugins.lite-xl-vibe.misc"

local vibe = {}

vibe.kb = require "plugins.lite-xl-vibe.keyboard"

vibe.mode = 'insert'

-- yeah, this is a test
core.error(vibe.mode:isUpperCase() and "true" or "false")



vibe.on_key_pressed__orig = keymap.on_key_pressed
function keymap.on_key_pressed(k)
  if dv():is(CommandView) then
    -- only original lite-xl mode in CommandViews
    -- .. for now at least
    return vibe.on_key_pressed__orig(k)
  end
  
end


core.log("lite-xl-vibe loaded.")
return vibe

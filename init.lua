-- mod-version:1 -- lite-xl 1.16
local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"

local misc = require "plugins.lite-xl-vibe.misc"

local vibe = {}

vibe.mode = 'insert'

-- yeah, this is a test
core.error(vibe.mode:isUpperCase() and "true" or "false")

core.log("lite-xl-vibe loaded.")
return vibe

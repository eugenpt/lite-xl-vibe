local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"

local misc = require "lite-xl-vibe.misc"

local vibe = {}

vibe.mode = 'insert'


core.error(vibe.mode:isUpperCase())

core.log("lite-xl-vibe loaded.")
return vibe

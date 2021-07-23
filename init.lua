-- mod-version:1 -- lite-xl 1.16
local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"

local misc = require "misc"

local vibe = {}

vibe.mode = 'insert'


core.error(vibe.mode:isUpperCase() and "true" or "false")

core.log("lite-xl-vibe loaded.")
return vibe

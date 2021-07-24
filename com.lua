
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"



local com = {}


command.add(nil, {
  ["vibe:switch-to-insert-mode"] = function()
    core.vibe.mode = "insert"
  end,
  ["vibe:switch-to-normal-mode"] = function()
    core.vibe.mode = "normal"
  end,
})

return com

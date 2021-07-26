
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local style = require "core.style"



local com = {}

com.caret_width__orig = style.caret_width

command.add(nil, {
  ["vibe:switch-to-insert-mode"] = function()
    core.vibe.mode = "insert"
  end,
  ["vibe:switch-to-normal-mode"] = function()
    core.vibe.mode = "normal"
  end,
  ["vibe:escape"] = function()
    core.vibe.reset_seq()
  end,
})

return com

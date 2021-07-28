
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local style = require "core.style"

local misc = require "plugins.lite-xl-vibe.misc"


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
  ["vibe:run-strokes"] = function()
    core.command_view:enter("Strokes to run:", function(text)
      core.vibe.run_stroke_seq(text)
    end)
  end,
  ["vibe:repeat"] = function()
    -- first - remove the last command (the `vibe:repeat` one)
    core.vibe.last_executed_seq = core.vibe.kb.split_stroke_seq(
            core.vibe.last_executed_seq
          )
    core.vibe.last_executed_seq = table.concat(
        {table.unpack(
          core.vibe.last_executed_seq,
          1,
          #core.vibe.last_executed_seq - 1
        )}
      )
    core.vibe.run_stroke_seq(core.vibe.last_executed_seq)
  end,
  ["vibe:repeat-find-in-line"] = function()
    if core.vibe.last_line_find == nil then
      core.vibe.debug_str = 'no last line search..'
      return
    end
    misc.find_in_line(core.vibe.last_line_find["symbol"], core.vibe.last_line_find["backwards"])
  end,
})

return com

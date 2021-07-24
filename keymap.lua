--[[

  All things keymap
  
 - some definitions necessary for vibe itself
 
 - some i/n/v maps (hopefully)
 
 - some old-style i-maps for better experience

]]--
local keymap = require "core.keymap"

-- Good, funally some N freaking map
keymap.nmap = {}
keymap.nmap_index = {} -- for sequence-based analysis
keymap.reverse_nmap = {} -- not really sure where to go with this..

function keymap.add_nmap(map)
  for stroke, commands in pairs(map) do
    if type(commands) == "string" then
      commands = { commands }
    end
    keymap.nmap[stroke] = commands
    for _, cmd in ipairs(commands) do
      keymap.reverse_nmap[cmd] = stroke
    end
  end
end



keymap.add_nmap {
  ["i"] = "vibe:switch-to-insert-mode",
}

-- some minor tweaks for isnert mode from emacs/vim/..
keymap.add_direct {
  ["ctrl+p"] = { "autocomplete:previous", "command:select-previous", "doc:move-to-previous-line" },
  ["ctrl+n"] = { "autocomplete:next", "command:select-next", "doc:move-to-next-line" },
  ["ctrl+h"] = "doc:backspace",
  ["ctrl+m"] = { "autocomplete:complete", "command:submit", "doc:newline", "dialog:select" },
  ["ctrl+["] = { "autocomplete:cancel", "command:escape", "vibe:switch-to-normal-mode", "doc:select-none", "dialog:select-no" },
  ["alt+x"] = "core:find-command",
  ["ctrl+a"] = "doc:move-to-start-of-line",
  ["ctrl+e"] = "doc:move-to-end-of-line",
  ["ctrl+w"] = "doc:delete-to-previous-word-start",
  ["escape"] = { "autocomplete:cancel", "command:escape", "vibe:switch-to-normal-mode", "doc:select-none", "dialog:select-no" },
}



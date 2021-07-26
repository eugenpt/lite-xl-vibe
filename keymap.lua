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
  ["C-P"] = "core:find-command",
  ["A-x"] = "core:find-command",
  [":"] = "core:find-command",
  -- navigation
  ["<left>"] = { "doc:move-to-previous-char", "dialog:previous-entry" },
  ["<right>"] = { "doc:move-to-next-char", "dialog:next-entry"},
  ["<up>"] = { "command:select-previous", "doc:move-to-previous-line" },
  ["<down>"] = { "command:select-next", "doc:move-to-next-line" },
  ["k"] = "doc:move-to-previous-line",
  ["j"] = "doc:move-to-next-line",
  ["h"] = "doc:move-to-previous-char",
  ["<backspace>"] = "doc:move-to-previous-char",
  ["l"] = "doc:move-to-next-char",
  ["b"] = "doc:move-to-previous-word-start",
  ["e"] = "doc:move-to-next-word-end",
  ["0"] = "doc:move-to-start-of-line",
  ["$"] = "doc:move-to-end-of-line",
  ["C-u"] = "doc:move-to-previous-page",
  ["C-d"] = "doc:move-to-next-page",
  ["["] = "doc:move-to-previous-block-start",
  ["]"] = "doc:move-to-next-block-end",
  ["G"] = "doc:move-to-end-of-doc",
  ["C-k"] = "root:switch-to-next-tab",
  ["C-j"] = "root:switch-to-previous-tab",
  -- well..  also sort of navigation?
  ["C-m"] = { "autocomplete:complete", "command:submit", "doc:move-to-next-line", "dialog:select" },
  -- simple editing
  ["J"] = "doc:join-lines",
  ["u"] = "doc:undo",
  ["C-r"] = "doc:redo",
  ["/"] = "find-replace:find",
  ["n"] = "find-replace:repeat-find",
  ["N"] = "find-replace:previous-find",
  -- I do like Mac bindings
  ["M-o"] = "core:open-file",
  ["M-n"] = "core:new-doc",
  ["M-s"] = "doc:save",
  -- the hint of Emacs (/ simple terminal bindings?)
  ["C-p"] = { "command:select-previous", "doc:move-to-previous-line" },
  ["C-n"] = { "command:select-next", "doc:move-to-next-line" },
  ["C-m"] = { "command:submit", "doc:newline", "dialog:select" },
  -- misc
  ["C-\\\\"] = "treeview:toggle", -- yeah, single \ turns into \\\\ , thats crazy.

  -- personal preferences
  ["C-h"] = "root:switch-to-left",
  ["C-l"] = "root:switch-to-right",
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



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

-- these are for single-stroke maps 
--  to be executed even when they are part of sequence
--    maybe I will use these for sth more than <ESC> and <C-g>
keymap.nmap_override = {}
keymap.reverse_nmap_override = {}

local function prep_list(s)
  return type(s) == "table" and s or {s}
end

local function fill_reverse(reverse, list, fill)
  for _,cmd in ipairs(list) do
    reverse[cmd] = fill
  end
end

function keymap.add_nmap(map)
  for stroke, commands in pairs(map) do
    commands = prep_list(commands)
    keymap.nmap[stroke] = commands
    fill_reverse(keymap.reverse_nmap, commands, stroke)
  end
end

function keymap.add_nmap_override(map)
  for stroke, commands in pairs(map) do
    commands = prep_list(commands)
    keymap.nmap_override[stroke] = commands
    fill_reverse(keymap.reverse_nmap_override, commands, stroke)
  end
end

function keymap.have_nmap_starting_with(seq)
  -- crude but it'll do for now
  for jseq,_ in pairs(keymap.nmap) do
    if #jseq>#seq and jseq:sub(1,#seq)==seq then
      return true
    end
  end
  return false
end


-- These are to be executed even when strokes appear in a sequence
keymap.add_nmap_override {
  ["C-g"] = "vibe:escape",
  ["<ESC>"] = "vibe:escape",
}

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
  ["gg"] = "doc:move-to-start-of-doc",
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
  ["return"] = { "autocomplete:complete", "command:submit", "doc:newline", "dialog:select" },
  ["keypad enter"] = { "autocomplete:complete", "command:submit", "doc:newline", "dialog:select" },
  ["ctrl+["] = { "autocomplete:cancel", "command:escape", "vibe:switch-to-normal-mode", "doc:select-none", "dialog:select-no" },
  ["alt+x"] = "core:find-command",
  ["ctrl+a"] = "doc:move-to-start-of-line",
  ["ctrl+e"] = "doc:move-to-end-of-line",
  ["ctrl+w"] = "doc:delete-to-previous-word-start",
  ["escape"] = { "autocomplete:cancel", "command:escape", "vibe:switch-to-normal-mode", "doc:select-none", "dialog:select-no" },
}



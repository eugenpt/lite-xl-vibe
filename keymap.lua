--[[

  All things keymap
  
 - some definitions necessary for vibe itself
 
 - some i/n/v maps (hopefully)
 
 - some old-style i-maps for better experience

]]--
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local translate = require "core.doc.translate"

local kb = require "plugins.lite-xl-vibe.keyboard"
local misc = require "plugins.lite-xl-vibe.misc"

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
    if reverse[cmd] == nil then
      reverse[cmd] = {}
    end
    table.insert(reverse[cmd], fill)
  end
end

function keymap.add_nmap(map)
  for stroke, commands in pairs(map) do
    commands = prep_list(commands)
    if keymap.nmap[stroke] == nil then
      keymap.nmap[stroke] = {}
    end
    for _,com in ipairs(commands) do
      table.insert(keymap.nmap[stroke], com)
    end
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
  for jseq, coms in pairs(keymap.nmap) do
    if #jseq>#seq and jseq:sub(1,#seq)==seq then
      for _,com in ipairs(coms) do
        if command.map[com]==nil or (command.map[com].predicate()) then
          return true
        end
      end
    end
  end
  return false
end

function keymap.nmap_starting_with(seq)
  local items = {}
  -- yeah..
  for jseq,com in pairs(keymap.nmap) do
    if #jseq>#seq and jseq:sub(1,#seq)==seq then
      if command.map[com]==nil or (command.map[com].predicate()) then
        table.insert(items, jseq)
      end
    end
  end
  return items
end

function keymap.mode_map()
  return core.vibe.mode == 'normal'
    and misc.table_join(keymap.nmap, keymap.nmap_override)
    or keymap.map
end


-- These are to be executed even when strokes appear in a sequence
keymap.add_nmap_override {
  ["C-g"] = "vibe:escape",
  ["C-["] = "vibe:escape",
  ["<ESC>"] = "vibe:escape",
  ["A-h"] = { "vibe:help:scroll", "vibe:help-suggest-stroke" },
}

keymap.add_nmap {
  ["i"] = "vibe:switch-to-insert-mode",
  ["C-P"] = "core:find-command",
  ["A-x"] = "core:find-command",
--  [":"] = "core:find-command",
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
  ["w"] = "doc:move-to-next-word-start",
  ["W"] = "doc:move-to-next-WORD-start",
  ["b"] = "doc:move-to-previous-word-start",
  ["B"] = "doc:move-to-previous-WORD-start",
  ["e"] = "doc:move-to-next-word-end",
  ["E"] = "doc:move-to-next-WORD-end",
  ["0"] = "doc:move-to-start-of-line",
  ["_"] = "0EB",
  ["$"] = "doc:move-to-end-of-line",
  ["C-u"] = "doc:move-to-previous-page",
  ["C-d"] = "doc:move-to-next-page",
  ["["] = "doc:move-to-previous-block-start",
  ["]"] = "doc:move-to-next-block-end",
  ["gg"] = "vibe:move-to-start-of-doc",
  ["G"] = "vibe:move-to-end-of-doc",
  ["C-k"] = "root:switch-to-next-tab",
  ["C-j"] = "root:switch-to-previous-tab",
  -- well..  also sort of navigation?
  ["C-m"] = { "autocomplete:complete", "command:submit", "doc:move-to-next-line", "dialog:select" },
  -- simple editing
  ["J"] = "doc:join-lines",
  ["u"] = "doc:undo",
  ["C-r"] = "doc:redo",
  ["/"] = "find-replace:find",
  [":s"] = "find-replace:replace",
  ["n"] = "find-replace:repeat-find",
  ["N"] = "find-replace:previous-find",
  ["dd"] = "<ESC>0vjd",
  [">>"] = "doc:indent",
  ["\\<\\<"] = "doc:unindent",
  [">"] = "vibe:indent",
  ["\\<"] = "vibe:unindent",
  
  -- these probably should be in vmap. if only someone created it.. ;)
  ["y"] = "vibe:copy",
  ["d"] = "vibe:delete",
  ["c"] = "vibe:change",
  
  ["x"] = "vibe:delete-symbol-under-cursor",
  -- actions through sequences, huh? I do like that.
  ["o"] = {"doc:move-to-other-edge-of-selection", "<ESC>$i<CR>"},
  ["O"] = "<ESC>0i<CR><ESC>ki<tab>",
  ["a"] = "li",
  ["A"] = "<ESC>$i",
  ["I"] = "<ESC>_i",
  ["C"] = "Di", 
  ["D"] = "<ESC>v$d",
  ["V"] = "<ESC>0vj",
  
  ["v$"] = "iS-<end><ESC>",
  ["y$"] = "v$y<ESC>",
  ["vv"] = "0vj",
  ["Y"] = "y$",
  ["yy"] = "0iS-<down><ESC>y<up>",
  ["p"] = "vibe:paste",
  
  ["*"] = "viw/<CR>n",  -- yeah, <CR> is an input to CommandView
  ["<delete>"] = "vibe:delete",
  
  --
  ["C-wv"] = "root:split-right",  
  ["C-ws"] = "root:split-down",
  
  
  -- I do like Mac bindings
  ["M-o"] = "core:open-file",
  ["M-n"] = "core:new-doc",
  ["M-s"] = "doc:save",
  -- the hint of Emacs (/ simple terminal bindings?)
  ["C-p"] = { "command:select-previous", "doc:move-to-previous-line" },
  ["C-n"] = { "command:select-next", "doc:move-to-next-line" },
  ["C-xC-;"] = "doc:toggle-line-comments",
  ["C-xh"] = "doc:select-all",
  ["A-y"] = "vibe:rotate-clipboard-ring",
  ["C-y"] = "vibe:rotate-clipboard-ring",
  -- ["C-x3"] = "root:split-right", -- hmm.. doesnt work since 3 is read as num_arg
  
  ["C-i"] = "vibe:history:move-back",
  ["C-o"] = "vibe:history:move-forward",
  
  -- hint of Doom emacs?
  ['<space><CR>'] = 'vibe:marks:create-or-move-to-named-mark',
  ['<space>m'] = 'vibe:marks:create-or-move-to-named-mark',
  ["<space>x"] = "vibe:open-scratch-buffer",
  ["<space>/"] = "project-search:fuzzy-find",
  ["<space>:"] = "A-x",
  ["<space>;"] = "core:exec-input",
  ["<space>C-;"] = "core:exec-input-and-insert",
  ["<space>,"] = "vibe:switch-to-tab-search",
  ["<space>."] = "core:find-file",
  ["<space>p"] = "vibe:registers:search-and-paste",
  ["<space>ir"] = "vibe:registers:search-and-paste",
  ["<space>y"] = "vibe:registers:search-and-copy",
  ["<space>qr"] = "core:restart",
  ["<space>qq"] = "core:quit",
  ["<space>qL"] = "vibe:workspace:open-workspace-file",
  ["<space>qs"] = "vibe:workspace:save-workspace",
  ["<space>qS"] = "vibe:workspace:save-workspace-as",
  ["<space>ff"] = "core:find-file",
  ["<space>fo"] = "core:open-file",
  ["<space>fi"] = "vibe:tabs-list",
  ["<space>fd"] = "root:close",
  ["<space>fk"] = "root:close",
  ["<space>fl"] = "vibe:switch-to-last-tab",
  ["<space>fn"] = "root:switch-to-next-tab",
  ["<space>f]"] = "root:switch-to-next-tab",
  ["<space>f["] = "root:switch-to-previous-tab",
  ["<space>fp"] = "root:switch-to-previous-tab",
  ["<space>fN"] = "core:new-doc",
  ["<space>fs"] = "doc:save",
  ["<space>fS"] = "doc:save-as",
  ["<space>bi"] = "vibe:tabs-list",
  ["<space>bd"] = "root:close",
  ["<space>bk"] = "root:close",
  ["<space>bl"] = "vibe:switch-to-last-tab",
  ["<space>bn"] = "root:switch-to-next-tab",
  ["<space>b]"] = "root:switch-to-next-tab",
  ["<space>b["] = "root:switch-to-previous-tab",
  ["<space>bp"] = "root:switch-to-previous-tab",
  ["<space>bN"] = "core:new-doc",
  ["<space>bs"] = "doc:save",
  ["<space>bS"] = "doc:save-as",
  ["<space>oj"] = "vibe:history:list-all",
  ["<space>oh"] = "vibe:history:list-all",
  ["<space>ol"] = "core:open-log",
  ["<space>oe"] = "core:exec-history",
  ["<space>om"] = "vibe:marks:show-all",
  ["<space>or"] = "vibe:registers-macro:list-all",
  ["<space>of"] = "vibe:open-file",
  ["<space>od"] = "vibe:open-select-dir",
  ["<space>o\\-"] = "vibe:open-select-dir",
  ["<space>sf"] = "core:find-file",
  ["<space>st"] = "vibe:switch-to-tab-search",
  ["<space>sF"] = "find-replace:find-pattern",
  ["<space>sp"] = "project-search:find",
  ["<space>sP"] = "project-search:fuzzy-find",
  ["<space>sj"] = "vibe:history:search",
  ["<space>sR"] = "vibe:registers-macro:list-all",
  ['<space>sm'] = 'vibe:marks:create-or-move-to-named-mark',
  ["<space>wv"] = "root:split-right",  
  ["<space>ws"] = "root:split-down",
  ["<space>wq"] = 'core:window-close',
  ["<space>wc"] = 'core:window:close-all-files',
  ["C-x0"] = 'core:window-close',
  ["C-x2"] = "root:split-down",
  ["C-x3"] = "root:split-right",
  -- toggles
  ["<space>tm"] = "minimap:toggle-visibility",
  -- ["<space>tt"] = "treeview:toggle",
  ["<space>tf"] = "core:toggle-fullscreen",
  ["<space>tc"] = "doc:toggle-line-comments",
  ["<space>tw"] = "draw-whitespace:toggle",
    
  -- misc
  ["C-\\\\"] = "treeview:toggle", -- yeah, single \ turns into \\\\ , thats crazy.
  
  -- 
  ["."] = "vibe:repeat",
  [";"] = "vibe:repeat-find-in-line",
  
  -- commands as in vim, just bindings for now..
  [":so<space>%<CR>"] = "core:exec-file",
  [":q<CR>"] = "root:close",
  [":e"] = "core:find-file",
  [":w<CR>"] = "doc:save",
  [":wC-m"] = "doc:save",
  [":w<space>"] = "doc:save-as",
  [":l"] = "core:open-log",
  [":s"] = "find-replace:replace",
  -- may be ok?
  [":s<CR>"] = "doc:save",
  [":s<space>"] = "doc:save-as",
  [":o"] = "core:find-file",
}

-------------------------------------------------------------------------------
-- project-search                                                            --
-------------------------------------------------------------------------------
keymap.add_nmap({
  ["r"] = "project-search:refresh",
  ["<f5>"] = "project-search:refresh",
  ["C-/"]  = "project-search:fuzzy-find", -- "project-search:find",
  ["k"]                 = "project-search:select-previous",
  ["j"]               = "project-search:select-next",
  ["<CR>"]             = "project-search:open-selected",
  ["C-u"]             = "project-search:move-to-previous-page",
  ["C-d"]           = "project-search:move-to-next-page",
  ["gg"]          = "project-search:move-to-start-of-doc",
  ["G"]           = "project-search:move-to-end-of-doc",
  -- also try'n'keep the usual mappings (why not?)
  ["C-F"]       = "project-search:find",
  ["<up>"]                 = "project-search:select-previous",
  ["<down>"]               = "project-search:select-next",
  ["<return>"]             = "project-search:open-selected",
  ["C-m"]             = "project-search:open-selected",
  ["<pageup>"]             = "project-search:move-to-previous-page",
  ["<pagedown>"]           = "project-search:move-to-next-page",
  ["C-<home>"]          = "project-search:move-to-start-of-doc",
  ["C-<end>"]           = "project-search:move-to-end-of-doc",
  ["<home>"]               = "project-search:move-to-start-of-doc",
  ["<end>"]                = "project-search:move-to-end-of-doc"
})
-------------------------------------------------------------------------------
-- ±same for my general ResultsView
-------------------------------------------------------------------------------
keymap.add_nmap({
  ["s"]                  = "vibe:results:sort",
  ["<f5>"] = "vibe:results:refresh",
  ["r"] = "vibe:results:refresh",
  ["/"]  = "vibe:results:search",
  ["C-f"]  = "vibe:results:search",
  ["k"]                 = "vibe:results:select-previous",
  ["j"]               = "vibe:results:select-next",
  ["<CR>"]             = "vibe:results:open-selected",
  ["C-u"]             = "vibe:results:move-to-previous-page",
  ["u"]             = "vibe:results:move-to-previous-page",
  ["C-d"]           = "vibe:results:move-to-next-page",
  ["d"]           = "vibe:results:move-to-next-page",
  ["gg"]          = "vibe:results:move-to-start-of-doc",
  ["G"]           = "vibe:results:move-to-end-of-doc",
  ["q"]             = "vibe:results:close",
  ["<ESC>"]             = "vibe:results:drop-search",

  -- also try'n'keep the usual mappings (why not?)
  ["<up>"]                 = "vibe:results:select-previous",
  ["<down>"]               = "vibe:results:select-next",
  ["<return>"]             = "vibe:results:open-selected",
  ["C-m"]             = "vibe:results:open-selected",
  ["<pageup>"]             = "vibe:results:move-to-previous-page",
  ["<pagedown>"]           = "vibe:results:move-to-next-page",
  ["C-<home>"]          = "vibe:results:move-to-start-of-doc",
  ["C-<end>"]           = "vibe:results:move-to-end-of-doc",
  ["<home>"]               = "vibe:results:move-to-start-of-doc",
  ["<end>"]                = "vibe:results:move-to-end-of-doc",
  ["<escape>"]             = "vibe:results:close",
})

-------------------------------------------------------------------------------
-- FileView
keymap.add_nmap({
  ["<backspace>"] = "vibe:fileview:go-back",
  ["H"] = "vibe:fileview:go-back",
  ["L"] = "vibe:fileview:go-forward",
  ["K"] = "vibe:fileview:go-up",
  ["C-k"] = "vibe:fileview:go-up",
  ["C-<left>"] = "vibe:fileview:go-back",
  ["C-<right>"] = "vibe:fileview:go-forward",
  ["C-<up>"] = "vibe:fileview:go-up",
})

-------------------------------------------------------------------------------
-- simple objects, no matching                                               --
-------------------------------------------------------------------------------
-- Seriously, for just ' and " this is so much overkill)).. 
local actions = {'v','y','d','c'}

local nmts = {
  ['i'] = {'T','t'},
  ['a'] = {'F','f'},
}

local objects = {'"',"'"}

for _,o in ipairs(objects) do
  for _,a in ipairs(actions) do
    for c,nmt in pairs(nmts) do
      keymap.add_nmap {
        [a..c..o] = nmt[1]..o..a..nmt[2]..o,
      }
    end
  end
end

------------------------------------------------------------------------------
-- snme minor tweaks for insert mode from emacs/vim/..                       --
-------------------------------------------------------------------------------
keymap.add_direct {
  ["alt+space"] = "<ESC><space>",
  ["ctrl+space"] = "<ESC>",
  ["ctrl+p"] = { "autocomplete:previous", "command:select-previous", "doc:move-to-previous-line" },
  ["ctrl+n"] = { "autocomplete:next", "command:select-next", "doc:move-to-next-line" },
  ["ctrl+h"] = "doc:backspace",
  ["ctrl+m"] = { "autocomplete:complete", "command:submit", "doc:newline", "dialog:select" },
  ["return"] = { "autocomplete:complete", "command:submit", "doc:newline", "dialog:select" },
  ["keypad enter"] = { "autocomplete:complete", "command:submit", "doc:newline", "dialog:select" },
  ["ctrl+["] = { "autocomplete:cancel", "command:escape", "vibe:switch-to-normal-mode", "doc:select-none", "dialog:select-no" },
  ["alt+x"] = "core:find-command",
  -- ["ctrl+a"] = "doc:move-to-start-of-line",
  ["ctrl+e"] = "doc:move-to-end-of-line",
  ["ctrl+w"] = "doc:delete-to-previous-word-start",
  ["escape"] = { "autocomplete:cancel", "command:escape", "vibe:switch-to-normal-mode", "doc:select-none", "dialog:select-no" },
  ["ctrl+shift+n"] = "core:new-doc",
  -- personal preferences
  ["ctrl+k"] = "root:switch-to-next-tab",
  ["ctrl+j"] = "root:switch-to-previous-tab",  
  -- ["ctrl+y"] = "vibe:rotate-clipboard-ring",
  ["alt+y"] = "vibe:rotate-clipboard-ring",
  ["ctrl+/"] = "project-search:fuzzy-find",
}

-------------------------------------------------------------------------------
-- I know this is ugly but.. hm. It kinda works                              --
-------------------------------------------------------------------------------

local com_name = ''
local com_name2 = ''
for _,i in ipairs(kb.all_typed_symbols) do

  local tr = {
    ['f'] = 'next-symbol',
    ['F'] = 'previous-symbol',
    ['t'] = 'next-symbol-excluded',
    ['T'] = 'previous-symbol-excluded',
  }
  for c, cname in pairs(tr) do
   keymap.add_nmap({
    ["v" .. c .. kb.escape_stroke(i)] = 'doc:select-to-'..cname..'-'..i,
    ["y" .. c .. kb.escape_stroke(i)] = 'v'..c..kb.escape_stroke(i)..'y',
    ["d" .. c .. kb.escape_stroke(i)] = 'doc:delete-to-'..cname..'-'..i,
    ["c" .. c .. kb.escape_stroke(i)] = 'd'..c..kb.escape_stroke(i)..'i',
  })
  end

  local tr = {
    ['F'] = 'previous-symbol',
    ['T'] = 'previous-symbol-excluded',
  }
  for c, cname in pairs(tr) do
   keymap.add_nmap({
    [c .. kb.escape_stroke(i)] = 'doc:move-to-'..cname..'-'..i,
  })
  end

  -- simple move works a bit differently ..
  -- all since symbol under the cursor is not included in selection when going forward 
  keymap.add_nmap({
    [ 'f' .. kb.escape_stroke(i)] = 'doc:move-to-next-symbol-excluded-'..i,
    [ 't' .. kb.escape_stroke(i)] = 'f'..kb.escape_stroke(i)..'h', -- who uses this?
   })
end

-- r/R

for _,c in ipairs(kb.all_typed_symbols) do
  local com_name ='vibe:replace-symbol-with-'..c 
  command.add(nil, {
    [ com_name ] = function()
      local doc = core.active_view.doc
      local line,col,line2,col2 = doc:get_selection()
      doc:set_selection(line,col)
      doc:delete_to(translate.next_char)
      doc:insert(line, col, c)
      doc:set_selection(line,col,line2,col2)
    end,
  })
  keymap.add_nmap({
    [ 'r'..kb.escape_stroke(c) ] = com_name,
  }) 
end

-- matching? WIP!

local object_letters = misc.copy(misc.matching_objectss)
object_letters['word'] = {'w'}
object_letters['WORD'] = {'W'}
object_letters['block'] = {'b','B','p','P'} -- `p` for Paragraph


for obj_name,obj_lets in pairs(object_letters) do
  for _,symbol in ipairs(obj_lets) do
    local stroke = kb.escape_stroke(symbol)
    keymap.add_nmap({
      ['vi'..stroke] = "doc:select-"..obj_name,
      ['yi'..stroke] = "vi"..stroke .. "y",
      ['di'..stroke] = "vi"..stroke .. "d",
      ['ci'..stroke] = "vi"..stroke .. "di",
    })
  end
end

-------------------------------------------------------------------------------
-- registers

for _,symbol in ipairs(kb.all_typed_symbols) do
  keymap.add_nmap({
    ['"'..kb.escape_stroke(symbol)] = "vibe:target-register-"..symbol,
  })
end

-------------------------------------------------------------------------------
-- macroses

for _,symbol in ipairs(kb.all_typed_symbols) do
  keymap.add_nmap({
    ["q"..kb.escape_stroke(symbol)] = "vibe:macro:start-recording-"..symbol,
    ["@"..kb.escape_stroke(symbol)] = "vibe:macro:play-macro-"..symbol,
  })
end
keymap.add_nmap({
  ["q"] = "vibe:macro:stop-recording",
})

-------------------------------------------------------------------------------
-- personal preferences
-------------------------------------------------------------------------------
keymap.add_nmap({
  ["C-h"] = "root:switch-to-left",
  ["C-l"] = "root:switch-to-right",
  [":r"] = "core:restart",
  ["A-j"] = "root:move-tab-left",
  ["A-k"] = "root:move-tab-right",
})

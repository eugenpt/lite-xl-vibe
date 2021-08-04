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
  ["C-["] = "vibe:escape",
  ["<ESC>"] = "vibe:escape",
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
  ["0"] = "doc:move-to-start-of-line",
  ["_"] = "0W",
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
  [":s"] = "find-replace:replace",
  ["n"] = "find-replace:repeat-find",
  ["N"] = "find-replace:previous-find",
  ["dd"] = "0iS-<down><ESC>d",
  [">>"] = "doc:indent",
  ["\\<\\<"] = "doc:unindent",
  
  -- these probably should be in vmap. if only someone created it.. ;)
  ["y"] = "vibe:copy",
  ["d"] = "vibe:delete",
  
  ["x"] = "vibe:delete-symbol-under-cursor",
  -- actions through sequences, huh? I do like that.
  ["o"] = "$i<CR>",
  ["O"] = "0i<CR><ESC>ki<tab>",
  ["a"] = "li",
  ["A"] = "$i",
  ["C"] = "Di", 
  ["D"] = "v$d",
  
  ["v$"] = "iS-<end><ESC>",
  ["y$"] = "v$y<ESC>",
  ["Y"] = "y$",
  ["yy"] = "0iS-<down><ESC>y<up>",
  ["p"] = "vibe:paste",
  
  ["*"] = "viw/<CR>n",  -- yeah, <CR> is an input to CommandView
  ["<delete>"] = "doc:delete",
  
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
  -- hint of Doom emacs?
  ["<space>x"] = "vibe:open-scratch-buffer",
  ["<space>:"] = "A-x",
  ["<space>ol"] = "core:open-log",
  ["<space>qr"] = "core:restart",
  ["<space>bd"] = "root:close",
  ["<space>bk"] = "root:close",
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
  
  -- personal preferences
  ["C-h"] = "root:switch-to-left",
  ["C-l"] = "root:switch-to-right",
  [":r"] = "core:restart",
}

-------------------------------------------------------------------------------
-- simple objects, no matching                                               --
-------------------------------------------------------------------------------
-- Seriously, for just ' and " this is so much overkill)).. 
local actions = {'v','d','c'}

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

-------------------------------------------------------------------------------
-- project-search                                                            --
-------------------------------------------------------------------------------
keymap.add_nmap({
  ["r"] = "project-search:refresh",
  ["<f5>"] = "project-search:refresh",
  ["C-/"]  = "project-search:find",
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
-- ±same for marks (should I make unified resultsview?                       --                                                         --
-------------------------------------------------------------------------------
keymap.add_nmap({
  ["<f5>"] = "vibe:marks:list:refresh",
  ["r"] = "vibe:marks:list:refresh",
  ["C-/"]  = "vibe:marks:list:find",
  ["k"]                 = "vibe:marks:list:select-previous",
  ["j"]               = "vibe:marks:list:select-next",
  ["<CR>"]             = "vibe:marks:list:open-selected",
  ["C-u"]             = "vibe:marks:list:move-to-previous-page",
  ["C-d"]           = "vibe:marks:list:move-to-next-page",
  ["gg"]          = "vibe:marks:list:move-to-start-of-doc",
  ["G"]           = "vibe:marks:list:move-to-end-of-doc",
  -- also try'n'keep the usual mappings (why not?)
  ["C-F"]       = "vibe:marks:list:find",
  ["<up>"]                 = "vibe:marks:list:select-previous",
  ["<down>"]               = "vibe:marks:list:select-next",
  ["<return>"]             = "vibe:marks:list:open-selected",
  ["C-m"]             = "vibe:marks:list:open-selected",
  ["<pageup>"]             = "vibe:marks:list:move-to-previous-page",
  ["<pagedown>"]           = "vibe:marks:list:move-to-next-page",
  ["C-<home>"]          = "vibe:marks:list:move-to-start-of-doc",
  ["C-<end>"]           = "vibe:marks:list:move-to-end-of-doc",
  ["<home>"]               = "vibe:marks:list:move-to-start-of-doc",
  ["<end>"]                = "vibe:marks:list:move-to-end-of-doc"
})

-------------------------------------------------------------------------------
-- some minor tweaks for isnert mode from emacs/vim/..                       --
-------------------------------------------------------------------------------
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
  ["ctrl+shift+n"] = "core:new-doc",
  -- personal preferences
  ["ctrl+k"] = "root:switch-to-next-tab",
  ["ctrl+j"] = "root:switch-to-previous-tab",  
  -- ["ctrl+y"] = "vibe:rotate-clipboard-ring",
  ["alt+y"] = "vibe:rotate-clipboard-ring",
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
object_letters['block'] = {'b','B'}


for obj_name,obj_lets in pairs(object_letters) do
  for _,symbol in ipairs(obj_lets) do
    local stroke = kb.escape_stroke(symbol)
    keymap.add_nmap({
      ['vi'..stroke] = "doc:select-"..obj_name,
      ['yi'..stroke] = "vi"..stroke .. "y",
      ['di'..stroke] = "vi"..stroke .. "d",
      ['ci'..stroke] = "di"..stroke .. "i",
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
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- VISUAL mode. Kind of.
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local ts = 'doc:move-to-'
local ts2 = 'doc:select-to-'
local ts3 = 'doc:delete-to-'
for bind,coms in pairs(keymap.nmap) do
  local com_name = misc.find_in_list(coms, function(item) return (item:sub(1,#ts)==ts) end)
  if com_name then
    
    local verbose = com_name:find_literal('-word-')
    if verbose then
    core.log('[%s] -> %s', bind, misc.str(coms))
    end
    
    local sel_name = ts2..com_name:sub(#ts+1)
    
    if verbose then
      core.log('sel_name=[%s]',sel_name)
      core.log('command.map[sel_name]=%s',misc.str(command.map[sel_name]))
    end
    
    if command.map[sel_name] then
      if verbose then
        core.log(sel_name)
      end
      
      -- make a command to do the same as sel- but only if we have selection
      local vibe_sel_name = 'vibe:'..sel_name:sub(5)
      if command.map[vibe_sel_name] == nil then
        command.add(misc.has_selection, {
          [vibe_sel_name] = function()
            command.perform(sel_name)
          end,
        })
      end
      -- and map it to be tried first
      table.insert(keymap.nmap[bind], 1, vibe_sel_name)
      -- and map the v<stroke> to do selection itself
      keymap.add_nmap({
        ['v'..bind] = sel_name,
        ['d'..bind] = 'v'..bind..'d',
      })
    end
  end
end


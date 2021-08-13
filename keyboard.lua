--[[

Module for all things keyboard
 ( am I aware that I am working on a text editor? 
    I mean, __keyboard-typing__ sort of text editor?
  yeah, I am
  
  Still, I firmly believe some things are (a little?)
    closer related to keyboard than others
  )

]]--
local keymap = require "core.keymap"


local keyboard = {}

-- I should probably take lite-xl one..
keyboard.modkey_map = {
  ["left command"]   = "cmd",
  ["right command"]  = "cmd",
  ["left windows"]   = "cmd",
  ["right windows"]  = "cmd",
  ["left ctrl"]   = "ctrl",
  ["right ctrl"]  = "ctrl",
  ["left shift"]  = "shift",
  ["right shift"] = "shift",
  ["left alt"]    = "alt",
  ["right option"]= "alt",
  ["left option"] = "alt",
  ["right alt"]   = "alt",
}

local modkeys = { "ctrl", "alt", "shift", "cmd", "vibe_magic"}

local modkeys_sh = {
  [ "ctrl" ] = "C",
  [ "alt" ] = "A",
  [ "shift" ] = "S",
  [ "cmd"  ] = "M",
  [ "vibe_magic" ] = "X-", -- imaginary keystroke, only for nmaps
}
local modkeys_sh__inv = {}
for a,b in pairs(modkeys_sh) do
  modkeys_sh__inv[b] = a
end


-- shift'ed keys to emulate shift (I know that's stupid but hey)
local shift_keys = {
  [";"] = ":",
  ["§"] = "±",
  ["`"] = "~",
  ["1"] = "!",
  ["2"] = "@",
  ["3"] = "#",
  ["4"] = "$",
  ["5"] = "%",
  ["6"] = "^",
  ["7"] = "&",
  ["8"] = "*",
  ["9"] = "(",
  ["0"] = ")",
  ["-"] = "_",
  ["="] = "+",
  ["["] = "{",
  ["]"] = "}",
  [";"] = ":",
  ["'"] = "\"",
  ["\\"] = "|",
  [","] = "<",
  ["."] = ">",
  ["/"] = "?",
}
-- also add letters
keyboard.letters = {}
keyboard.LETTERS = {}
keyboard.digits = {'0','1','2','3','4','5','6','7','8','9'}
local letterstr = "qwertyuiopasdfghjklzxcvbnm"
for i=1, #letterstr do
  shift_keys[letterstr:sub(i,i)] = letterstr:sub(i,i):upper()
  table.insert(keyboard.letters, letterstr:sub(i,i))
  table.insert(keyboard.LETTERS, letterstr:sub(i,i):upper())
end
keyboard.shift_keys = shift_keys

-- inverse, F -> f
local shift_keys_inv = {}
for a,b in pairs(shift_keys) do
  shift_keys_inv[b]=a
end

keyboard.all_typed_symbols = {' '} -- I know.
for a,b in pairs(shift_keys) do
  table.insert(keyboard.all_typed_symbols, a)
  table.insert(keyboard.all_typed_symbols, b)
end


local escape_char_sub = {
  ["<"] = "\\<",   -- for <ESC> and <CR>
  ["\\"] = "\\\\", -- for the escaping "\" itself -- it's a good thing I don't need triple escaping..
  ["-"] = "\\-",   -- for "-" in "C/A/M-.." 
  ["escape"] = "<ESC>",
  ["return"] = "<CR>",
  ["keypad enter"] = "<return>",
  [" "] = "<space>", -- I know.
} 
-- map back to symbol entered
--  should be handy? I mean.. it is already, for f/F
local un_escape_sub = {
  ["\\<"] = "<",
  ["\\\\"] = "\\",
  ["\\-"] = "-",
  ["<space>"] = " ",
  ["<CR>"] = "\n",
}
local escape_simple_keys = {
 'home','space','up','down','left','right','end','pageup','pagedown','delete','insert','tab','backspace'
}
-- add Fs
for i = 1, 64 do
  table.insert(escape_simple_keys, 'f' .. i)
end

keyboard.escape_char_sub__inv = {}
for a,b in pairs(escape_char_sub) do
  keyboard.escape_char_sub__inv[b] = a
end
for _,str in ipairs(escape_simple_keys) do
  escape_char_sub[str] = "<" .. str .. ">"
  -- so that these take precedence
  keyboard.escape_char_sub__inv["<"..str..">"] = str
end

-- I thought this would help with commandview submit in sequence
keyboard.escape_char_sub__inv["<CR>"] = "return"

function keyboard.escape_stroke(k)
  local r = escape_char_sub[k]
  if r then
    return r
  end
  return k
end

function keyboard.key_to_stroke(k)
  local stroke = ""
  -- prep modifiers
  for _, mk in ipairs({'ctrl','alt','altgr','cmd'}) do
    if keymap.modkeys[mk] then
      stroke = stroke .. modkeys_sh[mk] .. '-'
    end
  end
  -- Shift is special - it may be unnecessary
  if keymap.modkeys["shift"] then
    if shift_keys[k] then
      stroke = stroke .. keyboard.escape_stroke(shift_keys[k])
    else
      -- when necessary, add Shift as S-
      stroke = stroke .. 'S-' .. keyboard.escape_stroke(k)
    end
  else 
    stroke = stroke .. keyboard.escape_stroke(k)
  end
  return stroke
end

function keyboard.key_to_stroke__orig(k)
  local stroke = ""
  for _, mk in ipairs(modkeys) do
    if keymap.modkeys[mk] then
      stroke = stroke .. mk .. "+"
    end
  end
  return stroke .. k
end


local function stroke_strip_mod(stroke)
  -- strips C/A/M/S- from stroke
  --  returns:
  --    - old-style stroke mod-string (ctrl+/..)
  --    - stripped stroke
  --
  local lstroke = stroke
  local R = ''
  local s = ''
  while #lstroke>2 and lstroke:sub(2,2)=='-' do
    for sh,mod in pairs(modkeys_sh__inv) do
      s = string.match(lstroke, '^' .. sh .. '%-')
      if s then
        R = R .. mod .. '+'
        lstroke = lstroke:sub(#s+1,#lstroke)
      end
    end
  end
  return R, lstroke 
end

function keyboard.stroke_to_orig_stroke(stroke)
  local R, lstroke = stroke_strip_mod(stroke)
  -- if it's one of the escaped characters
  local s = keyboard.escape_char_sub__inv[lstroke]
  if s then
    return R .. s
  end
  -- check if shift'ed
  s = shift_keys_inv[lstroke]
  if s then
    R = R .. "shift+" .. s
  else
    R = R .. lstroke
  end  
  
  return R
end

function keyboard.stroke_to_symbol(stroke)
  local R, lstroke = stroke_strip_mod(stroke)
  local s = un_escape_sub[lstroke]
  if s then
    return s
  else
    -- if it is one symbol, return it
    --  otherwise - nil
    return #lstroke==1 and lstroke or nil
  end
end


keyboard.stroke_patterns = {
  '<[^>]+>',
  '\\.',
}
for _,sh in pairs(modkeys_sh) do
  table.insert(keyboard.stroke_patterns, sh .. '%-<[^>]+>')
  table.insert(keyboard.stroke_patterns, sh .. '%-\\.')
  table.insert(keyboard.stroke_patterns, sh .. '%-.')
end
table.insert(keyboard.stroke_patterns, '.')


function keyboard.split_stroke_seq(seq)
  local R = {}
  local ts = seq
  while #ts>0 do
    local match = ''
    for _,p in ipairs(keyboard.stroke_patterns) do
      match = string.match(ts,'^' .. p)
      if match then        
        break
      end
    end
    table.insert(R,match)
    ts = ts:sub(#match+1,#ts)
  end
  return R 
end

-- the other side of `the finer control`
function keymap.on_key_released(k)
  local mk = keyboard.modkey_map[k]
  if mk then
    keymap.modkeys[mk] = false
  end
end


return keyboard

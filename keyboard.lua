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
  ["right alt"]   = "altgr",
}

local modkeys = { "ctrl", "alt", "altgr", "shift", "cmd"}

local modkeys_sh = {
  [ "ctrl" ] = "C",
  [ "alt" ] = "A",
  [ "altgr" ] = "A",
  [ "shift" ] = "S",
  [ "cmd"  ] = "M",
}

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
local letterstr = "qwertyuioopasdfghjklzxcvbnm"
for i=1, #letterstr do
  shift_keys[letterstr:sub(i,i)] = letterstr:sub(i,i):upper()
end

local escape_char_sub = {
  ["<"] = "\\<",   -- for <ESC> and <CR>
  ["\\"] = "\\\\", -- for the escaping "\" itself -- it's a good thing I don't need triple escaping..
  ["-"] = "\\-",   -- for "-" in "C/A/M-.." 
  ["escape"] = "<ESC>",
  ["return"] = "<CR>",
  ["keypad enter"] = "<return>",
} 
-- should be handy? I mean.. it is already, for f/F
local un_escape_sub = {
  ["\\<"] = "<",
  ["\\\\"] = "\\",
  ["\\-"] = "-",
  ["<space>"] = " ",
}
local escape_simple_keys = {
 'home','space','up','down','left','right','end','pageup','pagedown','delete','insert','tab','backspace'
}
-- add Fs
for i = 1, 64 do
  table.insert(escape_simple_keys, 'f' .. i)
end
for _,str in ipairs(escape_simple_keys) do
  escape_char_sub[str] = "<" .. str .. ">"
end

local function escape_stroke(k)
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
      stroke = stroke .. escape_stroke(shift_keys[k])
    else
      -- when necessary, add Shift as S-
      stroke = stroke .. 'S-' .. escape_stroke(k)
    end
  else 
    stroke = stroke .. escape_stroke(k)
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

keyboard.stroke_patterns = {
  '<[^>]+>',
  '\\.',
  '.'
}

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

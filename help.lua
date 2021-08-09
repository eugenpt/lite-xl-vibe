local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local StatusView = require "core.statusview"

local kb = require "plugins.lite-xl-vibe.keyboard"
local misc = require "plugins.lite-xl-vibe.misc"
local ResultsView = require "plugins.lite-xl-vibe.ResultsView"

local help = {}

help.last_stroke_time = system.get_time()

help.group_hints = {
  ["<space>"] = "PREFIX ...",
  ['<space>b'] = 'Buffers/Files/taBs...',
  ['<space>o'] = 'Open...',
  ['<space>t'] = 'Toggle...',
  ['<space>q'] = 'App/Workspace...',
  ['v'] = 'Select to...',
  ['vi'] = 'Select inside...',
  ["v'"] = 'Select to mark...',
  ["v`"] = 'Select to mark...',
  ["vf"] = "Select to char(inclusive)...",
  ["vt"] = "Select to char...",
  ["vF"] = "Select(back) to char(inclusive)...",
  ["vT"] = "Select(back) to char...",
  ["m"] = 'Set Mark...',
  ['"'] = 'Register..',
  ["'"] = 'Go/Select to mark...',
  ["`"] = 'Go/Select to mark...',
  ["@"] = "Run macros...",
  [":"] = "Prefix (stuff..)...",
  ["*"] = "Find word under cursor",
}

function help.stroke_suggestions()
  -- start with dumb stroke suggestions
  local items = {}
  local short
  for _, item in ipairs(core.vibe.stroke_suggestions) do
    local found = nil
    for hint_stroke,hint in pairs(help.group_hints) do
      if (#item >= #hint_stroke)
         and (#hint_stroke > #core.vibe.stroke_seq)
         and item:sub(1,#hint_stroke)==hint_stroke then
        found = true
        short = hint_stroke
        break
      end
    end
    
    if found then
      items[short] = {help.group_hints[short]}
    else
      local map = keymap.nmap[item]
      if #map==1 and command.map[map[1]]==nil and keymap.nmap[map[1]] then
        -- remap to sequence
        items[item] = keymap.nmap[map[1]]
      else
        items[item] = map
      end
    end
  end
  
  local items_f = {}
  -- filter?
  for stroke, coms in pairs(items) do
    local hcoms = {}
    for _,com in ipairs(coms) do
      if command.map[com] and (not command.map[com].predicate()) then
        -- pass
      else
        table.insert(hcoms, com)
      end
    end
    if #hcoms>0 then
      items_f[stroke] = hcoms
    end
  end
  return items_f
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
command.add( nil, {
  ["vibe:help-suggest-stroke"] = function()
    core.vibe.flags['requesting_help_stroke_sugg'] = true
  end,
})

local font = style.code_font
local function get_line_height()
  return math.floor(font:get_height() * config.line_height)
end

local status = core.vibe.interface -- I know.

function status.draw_suggestions_box(self)
  if system.get_time() - help.last_stroke_time < config.vibe.stroke_sug_delay then
    return nil
  end
  
  local h = get_line_height()
  -- local x, y = self:get_content_offset()
  local rx, ry, rw, rh = self.position.x, self.position.y - h , self.size.x, h
  
  local Ss = core.vibe.help.stroke_suggestions()
  -- Sort the suggestions ..
  local strokes = misc.keys(Ss)
  table.sort(strokes)
  -- j for limitness. is that a word?
  local j=0
  
  local widths = {}
  local max_x = 0
  local min_x = 0
  
  local max_stroke_w = 0
  for _, stroke in ipairs(strokes) do
    if #stroke > max_stroke_w then
      max_stroke_w = #stroke
    end
  end

  local sj=0
  j = 0
  while sj<#strokes do
    sj = sj + 1
    local sug = strokes[sj]
    local coms = Ss[sug]
    j = j + 1
    if j>config.vibe.max_stroke_sugg then
      max_x = max_x + h
      if max_x + max_x - min_x > rw then
        -- next column will not fit
        break
      end
      min_x = max_x
      j = 1
    end
    
    local rx, ry, rw, rh = self.position.x, self.position.y - j*h , self.size.x, h
    renderer.draw_rect(rx + min_x, ry, rw, rh, style.background3)
    local x = common.draw_text(font, style.accent, " " .. (" "*(max_stroke_w - #sug)) ..sug:sub(#core.vibe.stroke_seq+1).."  |  ", nil, rx+min_x, ry, 0, h)
    x = common.draw_text(font, style.text, table.concat(coms,' '), nil, x, ry, 0, h)
    
    if x>max_x then 
      max_x = x
    end
  end
end

status.statusview__draw__orig = StatusView.draw

function StatusView:draw()
  status.statusview__draw__orig(self)
  core.root_view:defer_draw(status.draw_suggestions_box, self)
end


return help




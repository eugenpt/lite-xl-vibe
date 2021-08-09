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
    short = item:sub(1,#core.vibe.stroke_seq + 1)
    
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
      items[item] = keymap.nmap[item]
    end
  end
  
  -- filter?
  for stroke, coms in pairs(items) do
    local j=1
    while j<=#coms do
      if command.map[coms[j]] and (command.map[coms[j]].predicate()==false) then
        -- this is a command that is not active
        table.remove(coms, j)
      else
        j = j + 1
      end
    end
    if #coms == 0 then
      items[stroke] = nil
    end
  end
  return items
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
  local h = get_line_height()
  -- local x, y = self:get_content_offset()
  local rx, ry, rw, rh = self.position.x, self.position.y - h , self.size.x, h
  
  local Ss = core.vibe.help.stroke_suggestions()
  -- Sort the suggestions ..
  local strokes = misc.keys(Ss)
  table.sort(strokes)
  -- j for limitness. is that a word?
  local j=0
  for _, sug in ipairs(strokes) do
    local coms = Ss[sug]
    j = j + 1
    if j>config.vibe.max_stroke_sugg then
      break
    end
    
    local rx, ry, rw, rh = self.position.x, self.position.y - j*h , self.size.x, h
    renderer.draw_rect(rx, ry, rw, rh, style.background3)
    local x = common.draw_text(font, style.accent, sug:sub(#core.vibe.stroke_seq+1).."  |  ", nil, rx, ry, 0, h)
    common.draw_text(font, style.text, table.concat(coms,' '), nil, x, ry, 0, h)
  end
end

status.statusview__draw__orig = StatusView.draw

function StatusView:draw()
  status.statusview__draw__orig(self)
  core.root_view:defer_draw(status.draw_suggestions_box, self)
end


return help




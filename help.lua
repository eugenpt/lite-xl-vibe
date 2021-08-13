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

local vibe = core.vibe
local help = {}

help.last_stroke_time = system.get_time()

help.group_hints = {['normal'] = {
  [":"] = "Prefix (stuff..)...",
  ["<space>"] = "PREFIX ...",
  ['<space>f'] = 'Buffers/Files/taBs...',
  ['<space>b'] = 'Buffers/Files/taBs...',
  ['<space>o'] = 'Open...',
  ['<space>s'] = 'Search...',
  ['<space>t'] = 'Toggle...',
  ['<space>w'] = 'Window...',
  ['<space>q'] = 'App/Workspace...',

  ["m"] = 'Set Mark...',
  ["'"] = 'Go/Select to mark...',
  ["`"] = 'Go/Select to mark...',
  ["t"] = "Move to char...",
  ["f"] = "Move to char(inclusive)...",
  ["T"] = "Move(back) to char...",
  ["F"] = "Move(back) to char(inclusive)...",
  ['v'] = 'Select to...',
  ['vi'] = 'Select inside...',
  ["v'"] = 'Select to mark...',
  ["v`"] = 'Select to mark...',
  ["vf"] = "Select to char(inclusive)...",
  ["vt"] = "Select to char...",
  ["vF"] = "Select(back) to char(inclusive)...",
  ["vT"] = "Select(back) to char...",
  ["d"] = "Delete to..",
  ["d'"] = 'Delete to mark...',
  ["d`"] = 'Delete to mark...',
  ["df"] = "Delete to char(inclusive)...",
  ["dt"] = "Delete to char...",
  ["dF"] = "Delete(back) to char(inclusive)...",
  ["dT"] = "Delete(back) to char...",
  ["c"] = "Change to...",
  ["c'"] = 'Change to mark...',
  ["c`"] = 'Change to mark...',
  ["cf"] = "Change to char(inclusive)...",
  ["ct"] = "Change to char...",
  ["cF"] = "Change(back) to char(inclusive)...",
  ["cT"] = "Change(back) to char...",
  
  ["r"] = "Replace symbol with...",
    
  ["vi"] = "Select inside...",
  ["di"] = "Delete inside...",
  ["y"] = "Yank...",
  ["yi"] = "Yank(copy) inside...",
  ["ci"] = "Change inside...",

  ["q"] = "Start/Stop recording macro...",
  ["@"] = "Run macro...",
  ['"'] = 'Register..',
  ["*"] = "Find word under cursor",
},
['insert'] = {

}}

help.stroke_seq_for_sug = ''
function help.stroke_suggestions()
  if vibe.flags['requesting_help_stroke_sugg'] or #help.stroke_seq_for_sug>0 then
    if vibe.mode=='normal' then
      vibe.stroke_suggestions = keymap.nmap_starting_with(help.stroke_seq_for_sug)
    else
      vibe.stroke_suggestions = misc.keys(keymap.map)
    end
  else
    vibe.stroke_suggestions = {}
  end
  -- start with dumb stroke suggestions
  local group_hints = help.group_hints[core.vibe.mode] or {}
  local mode_map = keymap.mode_map()
  local items = {}
  local short
  for _, item in ipairs(core.vibe.stroke_suggestions) do
    local found = nil
    
    for j=#help.stroke_seq_for_sug+1,#item do
      local hint_stroke = item:sub(1,j)
      local hint = group_hints[hint_stroke]
      if hint then
        found = true
        short = hint_stroke
        break
      end
    end
    
    if found then
      items[short] = {group_hints[short]}
    else
      local map = mode_map[item]
      if map and #map==1 and command.map[map[1]]==nil and mode_map[map[1]] then
        -- remap to sequence
        items[item] = mode_map[map[1]]
      else
        items[item] = map
      end
    end
  end
  
  local items_f = {}
  -- filter only active commands
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


help.suggestions = {}
help.sug_strokes_sorted = {}
help.stroke_sug_len = 0

function help.update_suggestions()
  help.suggestions = help.stroke_suggestions()
  -- Sort the suggestions ..
  help.sug_strokes_sorted = misc.keys(help.suggestions)
  table.sort(help.sug_strokes_sorted)
  
  help.stroke_sug_len = #help.sug_strokes_sorted
  -- core.log("update sugg. count=%i", help.stroke_sug_len)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local font = style.code_font
local function get_line_height()
  return math.floor(font:get_height() * config.line_height)
end

function help.is_time_to_show_sug()
  return (system.get_time() - help.last_stroke_time) > config.vibe.stroke_sug_delay
end

local status = core.vibe.interface -- I know.

-- for `scrolling` suggestions
help.stroke_sug_shift = 0
help.stroke_sug_max_ix = 0

function status.draw_suggestions_box(self)
  if not help.is_time_to_show_sug() then
      help.is_showing = false
      help.stroke_sug_shift = 0
      return nil
  end
  
  local h = get_line_height()
  -- local x, y = self:get_content_offset()
  local rx, ry, rw, rh = self.position.x, self.position.y - h , self.size.x, h
  
  -- j for limitness. is that a word?
  local j=0
  
  local widths = {}
  local max_x = 0
  local min_x = 0
  
  local max_stroke_w = 0
  for _, stroke in ipairs(help.sug_strokes_sorted) do
    if #stroke > max_stroke_w then
      max_stroke_w = #stroke
    end
  end

  local sj=help.stroke_sug_shift
  j = 0
  while sj<#help.sug_strokes_sorted do
    sj = sj + 1
    help.stroke_sug_max_ix = sj
    local sug = help.sug_strokes_sorted[sj]
    local coms = help.suggestions[sug]
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

    help.is_showing = true
    
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

command.add( nil, {
  ["vibe:help-suggest-stroke"] = function()
    core.vibe.flags['requesting_help_stroke_sugg'] = true
    help.stroke_sug_shift = 0
  end,
})

command.add(function() return help.is_time_to_show_sug() end, {
  ["vibe:help:scroll"] = function()
    help.stroke_sug_shift = help.stroke_sug_max_ix
    if help.stroke_sug_shift >=   help.stroke_sug_len then
      help.stroke_sug_shift = 0
    end
    core.vibe.flags['requesting_help_stroke_sugg'] = true
  end,
})

keymap.add({
  ['alt+h'] = { "vibe:help:scroll", "vibe:help-suggest-stroke" },
})

return help




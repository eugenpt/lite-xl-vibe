-- mod-version:1 -- lite-xl 1.16
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local DocView = require "core.docview"
local CommandView = require "core.commandview"


local config = require "plugins.lite-xl-vibe.config"


local vibe = {}
core.vibe = vibe


local misc = require "plugins.lite-xl-vibe.misc"


vibe.kb = require "plugins.lite-xl-vibe.keyboard"
vibe.mode = 'insert'

vibe.debug_str = 'test debug_str'
vibe.last_stroke = ''
vibe.stroke_seq = ''
vibe.last_executed_seq = ''

vibe.translate = require "plugins.lite-xl-vibe.translate"
vibe.com = require "plugins.lite-xl-vibe.com"

require "plugins.lite-xl-vibe.keymap"

vibe.marks = require "plugins.lite-xl-vibe.marks"

vibe.interface = require "plugins.lite-xl-vibe.interface"




-- yeah, this is a test
core.error(vibe.mode:isUpperCase() and "true" or "false")


local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end

function vibe.reset_seq()
  vibe.stroke_seq = ''
end


vibe.flags = {}
vibe.flags['run_stroke_seq'] = false

function vibe.run_stroke_seq(seq)
  vibe.last_executed_seq = seq
  vibe.flags['run_stroke_seq'] = true
  if type(seq) ~= 'table' then
    seq = vibe.kb.split_stroke_seq(seq)
  end
  local did_input = false
  for _,stroke in ipairs(seq) do
    did_input = vibe.process_stroke(stroke)
    if not did_input then
      local symbol = vibe.kb.stroke_to_symbol(stroke)
      if symbol then
        local line,col = doc():get_selection()
        doc():insert(line, col, vibe.kb.stroke_to_symbol(stroke))
        doc():set_selection(line, col+1)
        doc()
      end
    end
  end
  vibe.flags['run_stroke_seq'] = false
end

command.add_hook("vibe:switch-to-insert-mode", function()
  if vibe.flags['run_stroke_seq'] == false then
    vibe.last_executed_seq = vibe.last_stroke
  end
end)

vibe.on_key_pressed__orig = keymap.on_key_pressed
function keymap.on_key_pressed(k)
  if dv():is(CommandView) then
    -- only original lite-xl mode in CommandViews
    -- .. for now at least
    return vibe.on_key_pressed__orig(k)
  end

  -- I need the finer control on this (I think..)
  local mk = vibe.kb.modkey_map[k]
  if mk then
    vibe.last_stroke = k
    keymap.modkeys[mk] = true
    -- work-around for windows where `altgr` is treated as `ctrl+alt`
    if mk == "altgr" then
      keymap.modkeys["ctrl"] = false
    end
    return false
  end
  -- now finally parse and process the stroke
  return vibe.process_stroke(vibe.kb.key_to_stroke(k))
end

function vibe.process_stroke(stroke)
    core.log_quiet("process_stroke |%s|", stroke)
    -- first - current stroke
    vibe.last_stroke = stroke
    
    if vibe.flags['run_stroke_seq'] == false then
      vibe.last_executed_seq = vibe.last_executed_seq .. stroke
    end
    
    if stroke=='C-g' then
      vibe.last_executed_seq = ''
    end
    
    local stroke__orig = vibe.kb.stroke_to_orig_stroke(stroke)
    local commands = {}
    
    vibe.debug_str = vibe.last_executed_seq
    vibe.stroke_seq = vibe.stroke_seq .. stroke
    
    if vibe.mode == "insert" then
      commands = keymap.map[stroke__orig]
      if commands then
        -- core.log_quiet('imapped to ' .. misc.str(commands))
      else
        -- core.log_quiet('insert,no coms')
      end
    elseif vibe.mode == "normal" then
      commands = keymap.nmap_override[vibe.last_stroke]
      if commands then 
        core.log_quiet('nmap_override to ' .. misc.str(commands))
      else
        commands = keymap.nmap[vibe.stroke_seq]
        
        if commands then
          core.log_quiet('nmapped to ' .. misc.str(commands))
        else  
          if not keymap.have_nmap_starting_with(vibe.stroke_seq) then
            core.log_quiet('no commands for ' .. vibe.stroke_seq)
            vibe.reset_seq()
          end
        end
      end
    end
    
    if commands then
      local performed = false
      for _, cmd in ipairs(commands) do
        if command.map[cmd] then
          performed = command.perform(cmd)
          if performed then break end
        else
          -- sequence!
          vibe.reset_seq()
          core.log_quiet('sequence as command! [%s]',cmd)
          vibe.run_stroke_seq(cmd)
          -- for now let's think of sequences as default-performed
          performed = true
          break
        end  
      end
      if performed then
        vibe.reset_seq()
      end
      core.log_quiet('have commands, return true')
      return true
    end    
    
    if vibe.mode=='insert' then
      core.log_quiet('mode==insert , return false')
      return false
    else
      core.log_quiet('mode != insert, return true')
      return true -- no text input in normal mode
    end
end


function vibe:get_mode_str()
  return self and (self.mode == 'insert' and "INSERT" or "NORMAL") or 'nil?'
end


core.log("lite-xl-vibe loaded.")
return vibe

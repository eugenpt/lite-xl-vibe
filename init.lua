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
vibe.kb = require "plugins.lite-xl-vibe.keyboard"
vibe.mode = 'insert'
vibe.debug_str = 'test debug_str'
vibe.last_stroke = ''
vibe.stroke_seq = ''
vibe.last_executed_seq = ''
vibe.num_arg = ''
vibe.flags = {}
vibe.flags['run_stroke_seq'] = false
vibe.flags['run_repeat_seq__started_clipboard'] = false
vibe.flags['run_repeat_seq'] = false
vibe.flags['recording_macro'] = false

vibe.target_register = nil
vibe.target_register = nil
vibe.registers = require("plugins.lite-xl-vibe.registers")

local misc = require "plugins.lite-xl-vibe.misc"
vibe.translate = require "plugins.lite-xl-vibe.translate"
require "plugins.lite-xl-vibe.keymap"
vibe.com = require "plugins.lite-xl-vibe.com"
vibe.marks = require "plugins.lite-xl-vibe.marks"
vibe.interface = require "plugins.lite-xl-vibe.interface"

require "plugins.lite-xl-vibe.FileView"

require "plugins.lite-xl-vibe.visual_mode"

require "plugins.lite-xl-vibe.vibeworkspace"

local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end

-------------------------------------------------------------------------------

function vibe.reset_seq()
  vibe.stroke_seq = ''
  vibe.num_arg = ''
end

function vibe.run_repeat_seq(seq, num)
  local run_repeat_seq = vibe.flags['run_repeat_seq']
  vibe.flags['run_repeat_seq'] = true
  vibe.flags['run_repeat_seq__started_clipboard'] = false
  vibe.reset_seq()
  for j=1,num do
    vibe.run_stroke_seq((vibe.mode=='insert' and '<ESC>' or '') .. seq)
  end
  vibe.flags['run_repeat_seq'] = run_repeat_seq
end

function vibe.run_stroke_seq(seq)
  vibe.last_executed_seq = seq
  local previous_run_stroke_seq = vibe.flags['run_stroke_seq']
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
  vibe.flags['run_stroke_seq'] = previous_run_stroke_seq
end

command.add_hook("vibe:switch-to-insert-mode", function()
  if vibe.flags['run_stroke_seq'] == false then
    vibe.last_executed_seq = vibe.last_stroke
  end
end)

vibe.on_key_pressed__orig = keymap.on_key_pressed
function keymap.on_key_pressed(k)
  core.log_quiet('key pressed : %s', k)
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
    local stroke__orig = vibe.kb.stroke_to_orig_stroke(stroke)
    
    if vibe.flags['run_stroke_seq'] then
      if dv():is(CommandView) then
        -- only original lite-xl mode in CommandViews
        -- .. for now at least
        if stroke=='<CR>' then
          -- a hack for sure, but a welcome one
          command.perform("command:submit")
          return true
        end
        core.log_quiet('orig_stroke %s', stroke__orig)
        return vibe.on_key_pressed__orig(stroke__orig)
      end
    else
      vibe.last_executed_seq = vibe.last_executed_seq .. stroke
      if vibe.flags['recording_macro'] then
        vibe.registers[vibe.recording_register] = 
          vibe.registers[vibe.recording_register]..stroke
        core.log_quiet('added,now reg = |%s|', vibe.registers[vibe.recording_register])
      end
    end
    
    if stroke=='C-g' then
      vibe.last_executed_seq = ''
    end
  
    local commands = {}
    
    vibe.debug_str = vibe.last_executed_seq
    vibe.stroke_seq = vibe.stroke_seq .. stroke
    
    if vibe.mode == "insert" then
      commands = keymap.map[stroke__orig]
      if commands then
        core.log_quiet('|%s| imapped to %s',stroke__orig,  misc.str(commands))
      else
        core.log_quiet('insert,no coms')
      end
    elseif vibe.mode == "normal" then
      commands = keymap.nmap_override[vibe.last_stroke]
      if commands then 
        core.log_quiet('nmap_override |%s| to %s', vibe.last_stroke, misc.str(commands))
      else
        commands = keymap.nmap[vibe.stroke_seq]

        if (stroke:isNumber() and not (vibe.num_arg=='' and stroke=='0'))then
          vibe.num_arg = vibe.num_arg .. stroke
          -- and also don't put it into seq
          vibe.stroke_seq = vibe.stroke_seq:sub(1,#vibe.stroke_seq - 1)
          return true
        end
        
        if commands then
          core.log_quiet('|%s| nmapped to %s', vibe.stroke_seq, misc.str(commands))
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
        
          if cmd == "vibe:repeat" then
            vibe.last_executed_seq = 
              vibe.last_executed_seq:sub_suffix_literal(vibe.stroke_seq,'')
            vibe.stroke_seq = ''
          end

          performed = command.perform(cmd)
        
          if performed then 
            if cmd:sub(1,5)=='vibe:' then
              -- pass. I expect my commands to make use of num_arg
            else
              -- simply repeat
              if vibe.num_arg~='' then 
                for j=1,tonumber(vibe.num_arg)-1 do
                  command.perform(cmd)
                end
              end
            end
            break 
          end
        else
          -- sequence!
          core.log_quiet('sequence as command! [%s]',cmd)
          if vibe.num_arg ~= '' then
            vibe.run_repeat_seq(cmd, tonumber(vibe.num_arg))
          else
            vibe.reset_seq()
            vibe.run_stroke_seq(cmd)
          end
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

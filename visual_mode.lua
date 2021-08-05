--[[

  VISUAL mode. Kind of.
  
  What I do here is I simply look for keymaps nmapping to move-to-<sth>
  
  Aand add v/d/c keymaps for select-to-/delete-to/change-to- <sth>

]]--

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local DocView = require "core.docview"
local CommandView = require "core.commandview"

local config = require "plugins.lite-xl-vibe.config"

local misc = require "plugins.lite-xl-vibe.misc"

local vibe = core.vibe

vibe.translate = require "plugins.lite-xl-vibe.translate"
require "plugins.lite-xl-vibe.keymap"

----------------------------------------------------------------------------

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


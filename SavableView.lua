--[[

Base class for all custom views to be saved with vibe.workspace

vibe.workspace checks for view.vibe_save and saves that if it exists

to create custom view, make SavableView:extend()

in :new(...):
 - set self.module to name of the class
   ( this should be doable automatically, right? I am not that deep into lua yet )
 
in :save_info():
 - return info, a serializable table containing all necessary info
 
in :load_info(info):
 - create your custom view based on info that you saved

]]--
local core = require "core"
local command = require "core.command"
local common = require "core.common"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"

local misc = require "plugins.lite-xl-vibe.misc"
local SavableView = View:extend()

function SavableView:new(title)
  SavableView.super.new(self)
  self.module = "SavableView"
  self.title=title or "Default title"
end

function SavableView:vibe_save()
  return { type='vibe_savable', module=self.module or "SavableView", info=self:save_info()}
end

function SavableView:save_info()
  -- placeholder for function returning serializable table 
  return {}
end

function SavableView.load_info(info)
  return nil -- SavableView()
end

return SavableView


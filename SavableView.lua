--[[

]]--
local core = require "core"
local command = require "core.command"
local common = require "core.common"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"

local misc = require "plugins.lite-xl-vibe.misc"
local SavableView = View:extend()

function SavableView:vibe_save()
  return { type='vibe_savable', module=self.module or "SavableView", info=self:save_info()}
end

function SavableView:save_info()
  -- placeholder for function returning serializable table 
  return {}
end

function SavableView.load_info(info)
  return SavableView()
end

return SavableView


local core = require "core"
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local translate = require "core.doc.translate"

local kb = require "plugins.lite-xl-vibe.keyboard"
local misc = require "plugins.lite-xl-vibe.misc"

local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end

-------------------------------------------------------------------------------

local translations = {}

for _,i in ipairs(kb.all_typed_symbols) do
  translations['next-symbol-'..i] = function(doc,line,col)
      return misc.find_in_line(i, false, true, doc,line,col)
  end
  translations['previous-symbol-'..i] = function(doc,line,col)
      return misc.find_in_line(i, true, true, doc,line,col)
  end
  translations['next-symbol-excluded-'..i] = function(doc,line,col)
      return misc.find_in_line(i, false, false, doc,line,col)
  end
  translations['previous-symbol-excluded-'..i] = function(doc,line,col)
      return misc.find_in_line(i, true, false, doc,line,col)
  end
end


local commands = {}

for name, fn in pairs(translations) do
  commands["doc:move-to-" .. name] = function() doc():move_to(fn, dv()) end
  commands["doc:select-to-" .. name] = function() doc():select_to(fn, dv()) end
  commands["doc:delete-to-" .. name] = function() doc():delete_to(fn, dv()) end
end

command.add(nil, commands)

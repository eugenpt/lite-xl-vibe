local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local DocView = require "core.docview"
local CommandView = require "core.commandview"
local style = require "core.style"
local config = require "core.config"
local common = require "core.common"
local translate = require "core.doc.translate"


function string:isUpperCase()
  return self:upper()==self and self:lower()~=self
end

function string:find_literal(substr)
  for j=1, (#self - #substr + 1) do
    if self:sub(j, j + #substr - 1) == substr then
      return j
    end
  end
  return nil
end

function string:isNumber()
  local s = '0123456789'
  for j=1,#self do
    if s:find_literal(self:sub(j,j)) == nil then
      return false
    end
  end
  return false
end

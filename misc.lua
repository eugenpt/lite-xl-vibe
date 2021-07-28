--[[

This is a miscellaneous module for lite-xl-vibe
(duh)

main intentions are

- to extend lite-xl (or lua) classes with necessary methods

- to add some minor things I personally find useful

- to dump things here if I don't have any other submodule for them

]]--
local core = require "core"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local DocView = require "core.docview"
local Doc = require "core.doc"
local CommandView = require "core.commandview"
local style = require "core.style"
local config = require "core.config"
local common = require "core.common"
local translate = require "core.doc.translate"

local misc = {}


local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end

-------------------------------------------------------------------------------
-- vim-like save to clipboard of all deleted text                            --
-------------------------------------------------------------------------------

local on_text_change__orig = Doc.on_text_change
function Doc:on_text_change(type)
  on_text_change__orig(self,type)
  
  if type == "remove" then
    system.set_clipboard(self.undo_stack[self.undo_stack.idx-1][3])
  end
end

-------------------------------------------------------------------------------
-- clipboard ring                                                            --
-------------------------------------------------------------------------------

core.vibe.clipboard_ring = {}
core.vibe.clipboard_ring_ix = 0
misc.system__set_clipboard = system.set_clipboard
misc.system__set_clipboard_ix = 0
function system.set_clipboard(s)
  core.vibe.clipboard_ring[#core.vibe.clipboard_ring + 1] = s
  core.vibe.clipboard_ring_ix = #core.vibe.clipboard_ring
  core.vibe.clipboard_ring[#core.vibe.clipboard_ring - config.vibe.clipboard_ring_max] = nil
  misc.system__set_clipboard(s)
end 


function misc.clipboard_ring_rotate()
  doc():undo()
  core.vibe.clipboard_ring_ix = core.vibe.clipboard_ring_ix - 1
  if core.vibe.clipboard_ring[core.vibe.clipboard_ring_ix] == nil then
    core.vibe.clipboard_ring_ix = #core.vibe.clipboard_ring
  end
  misc.system__set_clipboard(core.vibe.clipboard_ring[core.vibe.clipboard_ring_ix])
  command.perform("doc:paste")
end

-------------------------------------------------------------------------------
-- Translations                                                              --
-------------------------------------------------------------------------------

local function is_non_word(char)
  return config.non_word_chars:find(char, nil, true)
end

function translate.next_word_start(doc, line, col)
  local prev
  local end_line, end_col = translate.end_of_doc(doc, line, col)
  while line < end_line or col < end_col do
    prev = doc:get_char(line, col)
    local line2, col2 = doc:position_offset(line, col, 1)
    local char = doc:get_char(line2, col2)
    line, col = line2, col2
    if is_non_word(prev) and not is_non_word(char)
    -- or line == line2 and col == col2 
    then
      break
    end
  end
  return line, col
end

local translations = {
  ["next-word-start"] = translate.next_word_start,
}

local commands = {}
for name, fn in pairs(translations) do
  commands["doc:move-to-" .. name] = function() doc():move_to(fn, dv()) end
  commands["doc:select-to-" .. name] = function() doc():select_to(fn, dv()) end
  commands["doc:delete-to-" .. name] = function() doc():delete_to(fn, dv()) end
end
command.add("core.docview", commands)

-------------------------------------------------------------------------------

function string:isUpperCase()
  return self:upper()==self and self:lower()~=self
end

function string:find_literal(substr)
  -- literal find, instead of pattern-based 
  --  lua may have it, but I am not aware of it
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
  return true
end



local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end

function misc.str(a)
  if type(a) == 'table' then
    local R = '[ '
    for j,ja in pairs(a) do
      R = R .. (#R>2 and ', ' or '') .. '[' .. j .. '] = ' .. misc.str(ja)
    end
    R = R .. ' ]'
    return R
  elseif type(a) == 'string' then
    return '"' .. a .. '"'
  else
    return tostring(a)
  end
end

function misc.move_to_line(line)
  doc():move_to(function() return tonumber(num_arg),0 end, dv())
end

function misc.append_line_if_last_line(line)
  if line >= #doc().lines then
    doc():insert(line, math.huge, "\n")
  end
end

function misc.find_in_line(symbol, backwards, include, _doc, _line, _col)
  core.vibe.last_line_find = { 
    ["backwards"] = backwards, 
    ["symbol"] = symbol, 
    ["include"] = include,
  }
  if _doc == nil then
    _doc = doc()
    _line, _col = doc():get_selection()
  end

  local line = _line
  local col = _col
  local char
  while true do
    local line2, col2 = _doc:position_offset(line, col, backwards and -1 or 1)
    if char == symbol and (not backwards) and include then
      -- going forward we need to get this extra symbol
      return line2, col2
    end
    char = _doc:get_char(line2, col2)
    if char==symbol then
      if backwards then
        if include then
          return line2, col2
        else
          return line, col
        end
      else  
        if include then
          -- pass
        else
          return line2, col2
        end
      end
    end
    if line ~= line2 or col == col2 then
      core.vibe.debug_str = symbol .. ' not found'
      return _line, _col
    end
    line, col = line2, col2
  end    
end



-------------------------------------------------------------------------------
-- hooks, everyone?
-------------------------------------------------------------------------------

command.hooks = {}
local command_perform = command.perform
function command.perform(...)
  local r = command_perform(...)
  local list = {...}
  local name = list[1]
  if command.hooks[name] then
    for _,hook in ipairs(command.hooks[name]) do
      -- TODO : predicates?
      core.try(table.unpack(hook)) -- yeah, just add function and arguments as hooks
    end
  end
  return r -- wow, almost forgot this! man it took a long time to debug
end
function command.add_hook(com_name, hook)
   if command.hooks[com_name]==nil then
     command.hooks[com_name] = {}
   end
   if type(hook) == 'function' then
     hook = { hook }
   end
   table.insert(command.hooks[com_name], hook)
end

-------------------------------------------------------------------------------
-- commands
-------------------------------------------------------------------------------

command.add(nil, {
  -- I find this sort of useful for debugging
  --   (it may be already present in lite/lite-xl,
  --      but it was easier for me to just write it )
  ["core:exec-selection"] = function()
    local text = doc():get_text(doc():get_selection())
    if doc():has_selection() then
      text = doc():get_text(doc():get_selection())
    else
      local line, col = doc():get_selection()
      doc():move_to(translate.start_of_line, dv())
--      doc():move_to(translate.next_word_start, dv())
      doc():select_to(translate.end_of_line, dv())
      if doc():has_selection() then
        text = doc():get_text(doc():get_selection())
      else
        return nil  
      end
      doc():move_to(function() return line, col end, dv())
    end
    assert(load(text))()
  end,
  -- after some thoughts this was even more useful
  --  ( I mean you do need to `require` a lot of stuff.. )
  ["core:exec-file"] = function()
    assert(load(table.concat(doc().lines)))()
  end,

--[[  
  -- yeah, I do like vim
  ["so % core:exec-file"] = function()
    command.perform("core:exec-file")
  end,
  ["w doc:save"] = function()
    command.perform("doc:save")
  end,  
  ["q root:close"] = function()
    command.perform("root:close")
  end,
]]--
})

-------------------------------------------------------------------------------
-- Keyboard-only confirm close

misc.core__confirm_close_all__orig = core.confirm_close_all
function core.confirm_close_all(close_fn, ...)
  local dirty_count = 0
  local dirty_name
  for _, doc in ipairs(core.docs) do
    if doc:is_dirty() then
      dirty_count = dirty_count + 1
      dirty_name = doc:get_name()
    end
  end
  if dirty_count > 0 then
    local text
    if dirty_count == 1 then
      text = string.format("\"%s\" has", dirty_name)
    else
      text = string.format("%d docs have", dirty_count)
    end
    text = text .. " unsaved changes. Quit anyway? [Yes / No]"
    local args = {...}
    core.command_view:enter(text, function(_, item)
      if item.text:match("^[yY]") then
        close_fn(table.unpack(args))
      elseif item.text:match("^[nN]") then
        -- nop
      end
    end, function(text)
      local items = {}
      if not text:find("^[^yY]") then table.insert(items, "Yes (Close Without Saving)") end
      if not text:find("^[^nN]") then table.insert(items, "No (Cancel close)") end
      return items
    end)
  else
    close_fn(...)
  end
end
  
-------------------------------------------------------------------------------

return misc

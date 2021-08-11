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

translations["next-word-start"] = translate.next_word_start

-------------------------------------------------------------------------------
-- WORDs
-------------------------------------------------------------------------------
local function is_non_WORD(char)
  return config.non_WORD_chars:find(char, nil, true)
end

function translate.previous_WORD_start(doc, line, col)
  local prev
  while line > 1 or col > 1 do
    local l, c = doc:position_offset(line, col, -1)
    local char = doc:get_char(l, c)
    if prev and prev ~= char or not is_non_WORD(char) then
      break
    end
    prev, line, col = char, l, c
  end
  return translate.start_of_WORD(doc, line, col)
end


function translate.next_WORD_end(doc, line, col)
  local prev
  local end_line, end_col = translate.end_of_doc(doc, line, col)
  while line < end_line or col < end_col do
    local char = doc:get_char(line, col)
    if prev and prev ~= char or not is_non_WORD(char) then
      break
    end
    line, col = doc:position_offset(line, col, 1)
    prev = char
  end
  return translate.end_of_WORD(doc, line, col)
end


function translate.start_of_WORD(doc, line, col)
  while true do
    local line2, col2 = doc:position_offset(line, col, -1)
    local char = doc:get_char(line2, col2)
    if is_non_WORD(char)
    or line == line2 and col == col2 then
      break
    end
    line, col = line2, col2
  end
  return line, col
end


function translate.end_of_WORD(doc, line, col)
  while true do
    local line2, col2 = doc:position_offset(line, col, 1)
    local char = doc:get_char(line, col)
    if is_non_WORD(char)
    or line == line2 and col == col2 then
      break
    end
    line, col = line2, col2
  end
  return line, col
end

function translate.next_WORD_start(doc, line, col)
  local prev
  local end_line, end_col = translate.end_of_doc(doc, line, col)
  while line < end_line or col < end_col do
    prev = doc:get_char(line, col)
    local line2, col2 = doc:position_offset(line, col, 1)
    local char = doc:get_char(line2, col2)
    line, col = line2, col2
    if is_non_WORD(prev) and not is_non_WORD(char)
    -- or line == line2 and col == col2 
    then
      break
    end
  end
  return line, col
end



translations["previous-WORD-start"] = translate.previous_WORD_start
translations["next-WORD-end"] = translate.next_WORD_end
translations["next-WORD-start"] = translate.next_WORD_start

-------------------------------------------------------------------------------
-- symbols
-------------------------------------------------------------------------------

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

-- matching

for _,objects in pairs(misc.matching_objectss) do
  local symbol = objects[1]
  local symbol_match = objects[2]
  local object_name = symbol..symbol_match
  for include=0,1 do
    local include_suffix = include==1 and '-inluded' or ''
    translations['previous-'..object_name..'-start'..include_suffix] = function(doc, line, col)
      return misc.find_in_line_unmatched(symbol, symbol_match, true, include==1, doc, line, col)
    end
    translations['next-'..object_name..'-end'..include_suffix] = function(doc, line, col)
      return misc.find_in_line_unmatched(symbol_match, symbol, false, include==1, doc, line, col)
    end
  end
end

-------------------------------------------------------------------------------

local commands = {}

for name, fn in pairs(translations) do
  commands["doc:move-to-" .. name] = function() doc():move_to(fn, dv()) end
  commands["doc:select-to-" .. name] = function() doc():select_to(fn, dv()) end
  commands["doc:delete-to-" .. name] = function() doc():delete_to(fn, dv()) end
end

command.add("core.docview", commands)

--

command.add(misc.has_selection, {
  ["doc:move-to-selection-start"] = function()
    local line,col,line2,col2 = doc():get_selection(true) -- true for sort
    doc():set_selection(line,col,line2,col2)
  end,
  ["doc:move-to-selection-end"] = function()
    local line,col,line2,col2 = doc():get_selection(true) -- true for sort
    doc():set_selection(line2,col2,line,col)
  end,
  ["doc:move-to-other-edge-of-selection"] = function()
    local line,col,line2,col2 = doc():get_selection() -- true for sort
    doc():set_selection(line2,col2,line,col)
  end,
})

-- 

local objects = misc.keys(misc.matching_objectss)
-- objects[#objects+1] = 'word' -- this one exists already
objects[#objects+1] = 'block'   -- Why doesn't this one exist?
objects[#objects+1] = 'WORD'

for _, obj in ipairs(objects) do
command.add("core.docview",{
  ["doc:select-"..obj] = function()
    -- in case of selection, go to start of it
    if misc.has_selection() then
      -- repeated backwards search needs to be jump-started
      command.perform("doc:move-to-selection-start")
      command.perform("doc:select-to-previous-char")
    end
    command.perform("doc:select-to-previous-"..obj.."-start")
    command.perform("doc:move-to-selection-end")
    command.perform("doc:select-to-next-"..obj.."-end")
  end,
})
end


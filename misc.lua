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

-- for tests
local test

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
-- allright, it does work but damn it's useless when I use x
--  maybe I should accumulate characters from xs into one ring item? hmm..
--    for now moved all that to vibe:delete

-- local on_text_change__orig = Doc.on_text_change
-- function Doc:on_text_change(type)
--   on_text_change__orig(self,type)
--   if type == "remove" then
--     system.set_clipboard(self.undo_stack[self.undo_stack.idx-1][3])
--   end
-- end

-------------------------------------------------------------------------------
-- clipboard ring                                                            --
-------------------------------------------------------------------------------

core.vibe.clipboard_ring = {}
core.vibe.clipboard_ring_ix = 0
misc.system__set_clipboard = system.set_clipboard
misc.system__set_clipboard_ix = 0
function system.set_clipboard(s, skip_ring)
  if s == nil then
    return
  end
  if core.vibe.flags['run_repeat_seq'] then
    if core.vibe.flags['run_repeat_seq__started_clipboard']==false then
      core.vibe.clipboard_ring[#core.vibe.clipboard_ring+1]=''
    end
    core.vibe.flags['run_repeat_seq__started_clipboard'] = true
    -- accumulate repeated stuff
    core.vibe.clipboard_ring[#core.vibe.clipboard_ring] = 
        core.vibe.clipboard_ring[#core.vibe.clipboard_ring] .. s
    core.vibe.clipboard_ring_ix = #core.vibe.clipboard_ring
    core.vibe.clipboard_ring[#core.vibe.clipboard_ring 
                             - config.vibe.clipboard_ring_max] = nil
    misc.system__set_clipboard(core.vibe.clipboard_ring[#core.vibe.clipboard_ring])
  else
    if skip_ring then
      -- pass
    else
      core.vibe.clipboard_ring[#core.vibe.clipboard_ring + 1] = s
      core.vibe.clipboard_ring_ix = #core.vibe.clipboard_ring
      core.vibe.clipboard_ring[#core.vibe.clipboard_ring - config.vibe.clipboard_ring_max] = nil
    end
    misc.system__set_clipboard(s)
  end
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

local function str_mul(str,num)
  local r = ''
  for j=1,num do
    r = r .. str
  end
  return r
end

getmetatable('string').__mul = function(s,n)
  if type(s)=='string' then
    if type(n)=='string' then
      -- like.. ??
      return s*tonumber(n)
    else
      return str_mul(s,n)
    end
  else
    return str_mul(n,s)  
  end
end

function string:isUpperCase()
  return self:upper()==self and self:lower()~=self
end

-- substitute suffix, literally (no patterns!)
--  kinda like :gsub(suffix..'$', sub)
--    but then suffix should be escaped and I'm lazy..
function string:sub_suffix_literal(suffix, sub)
  if self:sub(#self-#suffix+1)==suffix then
    return self:sub(1, #self - #suffix)..sub, 1 -- don't forget the count
  end
  return self, 0
end

test = 'string_suffix'
assert(test:sub_suffix_literal('suffix','sub')=='string_sub')



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

function misc.path_is_win_drive(path)
  return (#path==2)and(path:sub(2,2)==':') 
end

function misc.path_up(path)
  if misc.path_is_win_drive(path) then
    -- Windows, drive level
    --  up = '', alias for 'all drives are subfolders'
    return ''
  end
  return path:gsub(PATHSEP..'[^'..PATHSEP..']+$','')
end

function misc.slice(table,i0,i1)
  i0 = i0 or 1
  i1 = i1 or #table
  local r = {}
  for i=i0,i1 do
    r[#r+1]=table[i]
  end
  return r
end

function misc.copy(table, deep)
  local r = {}
  if type(table) ~= 'table' then
    return table
  end
  for k,v in pairs(table) do
    r[k] = deep and misc.copy(v, deep) or v
  end
  return r
end

function misc.keys(table)
  local r = {}
  for a,_ in pairs(table) do
    r[#r+1]=a
  end
  return r
end

function misc.list_unique(list)
  local r = {}
  for _,a in ipairs(list) do
    r[a] = 1
  end
  return misc.keys(r)
end

function misc.values(table)
  local r = {}
  for _,a in pairs(table) do
    r[#r+1]=a
  end
end

function misc.list_contains(list, fun)
  for _,item in ipairs(list) do
    if fun(item) then
      return true
    end
  end
  return false
end

function misc.list_reverse(list)
  local A = {}
  for j=#list,1,-1 do
    table.insert(A,list[j])
  end
  return A
end

function misc.find_in_list(list, fun)
  for _,item in ipairs(list) do
    if fun(item) then
      return item
    end
  end
  return nil
end

function misc.compare_key_fun(key)
  return function(a,b) return a[key]>b[key] end
end

function misc.fuzzy_match_key(list, key, needle, files)
  local res = {}
  for _, item in ipairs(list) do
    local score = system.fuzzy_match(tostring(item[key]), needle, files)
    if score then
      table.insert(res, { text = item, score = score })
    end
  end
  table.sort(res, misc.compare_key_fun('score'))
  for i, item in ipairs(res) do
    res[i] = item.text
  end
  return res
end

-------------------------------------------------------------------------------
-- Files
-------------------------------------------------------------------------------

function misc.list_drives()
  local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local R = { dirs={}, files={} }
  for j=1,#letters do
    local path = letters:sub(j,j)..':'..'\\'
    local info = system.get_file_info(path)
    if info then 
      info.filename = path
      info.abs_filename = letters:sub(j,j)..':'
      table.insert(R.dirs, info)
      
    end
  end
  return R
end

function misc.list_dir(path)
  core.log('misc.list_dir, path=%s',path)
  if path == '' then
    return misc.list_drives()
  end
  local all = system.list_dir(misc.path_is_win_drive(path) and (path..'\\') or path) or {}
  local R = { dirs={}, files = {} }
  for _, file in ipairs(all) do
      local info = system.get_file_info(path .. PATHSEP .. file)
      info.filename = file
      info.abs_filename = path .. PATHSEP .. file
      table.insert(info.type == "dir" and R.dirs or R.files, info)
  end
  return R
end


-- https://stackoverflow.com/a/4991602/2624911
function misc.file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function misc.get_tabs_list()
  local items = {}
  for _, doc in ipairs(core.docs) do
    table.insert(items, {
      ["text"]   = doc.abs_filename,
      ["doc"] = doc,
      ["title"] = "",
    })
  end
  core.log('items_fun : %i items',#items)
  return items
end


function misc.text_width(font, _, text, _, x)
  return x + font:get_width(text)
end

-------------------------------------------------------------------------------
-- scratch

function misc.scratch_filepath()
  return USERDIR .. PATHSEP .. "scratch.lua"
end

if not misc.file_exists(misc.scratch_filepath()) then
  local fp = assert( io.open(misc.scratch_filepath(), "wb") )
end


local function dv()
  return core.active_view
end

local function doc()
  return core.active_view.doc
end

local tablestr_depth = 0
local function str(a)
  local prefix = ' ' * tablestr_depth
  tablestr_depth = tablestr_depth + 1
  local R = ''
  if type(a) == 'table' then
    if tablestr_depth > (config.vibe.misc_str_max_depth or 4) then
      R = '<table>'
    else
      R = '{'
      for j,ja in pairs(a) do
        R = R .. '\n' .. prefix .. '[' .. tostring(j) .. '] = ' .. str(ja)
      end
      R = R .. '\n' .. prefix .. '}'
    end
  elseif type(a) == 'string' then
    R = '"' .. a .. '"'
  else
    R = tostring(a)
  end
  tablestr_depth = tablestr_depth - 1
  return prefix .. R
end

function misc.str(a)
  tablestr_depth = 0
  return str(a)
end

function misc.has_selection()
  return core.active_view:is(DocView) and core.active_view.doc:has_selection()
end

function misc.drop_selection()
  local line,col = doc():get_selection()
  doc():set_selection(line,col)
end

function misc.move_to_line(line)
  doc():move_to(function() return line,0 end, dv())
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

-- these are used later for translations and such
--  must be in order
misc.matching_objectss = {
  ['<>'] = {'<','>'},
  ['()'] = {'(',')'},
  ['[]'] = {'[',']'},
  ['{}'] = {'{','}'},
}

function misc.find_in_line_unmatched(symbol,symbol_match,backwards,include,_doc,_line,_col)
  if _doc == nil then
    _doc = doc()
    _line, _col = doc():get_selection()
  end

  local line = _line
  local col = _col
  local char
  
  local n_unmatched = 0
  while true do
    local line2, col2 = _doc:position_offset(line, col, backwards and -1 or 1)
    if char == symbol and n_unmatched==0 and (not backwards) and include then
      -- going forward we need to get this extra symbol
      return line2, col2
    end
    if char==symbol then
      n_unmatched = n_unmatched - 1
    end
    char = _doc:get_char(line2, col2)
    if char==symbol_match then
      n_unmatched = n_unmatched + 1
    end
    if char==symbol and n_unmatched == 0 then
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

function misc.local_path()
  return debug.getinfo(2, "S").source:sub(2):gsub(PATHSEP..'[^'..PATHSEP..']*$','')
end
-------------------------------------------------------------------------------
-- file with all the requires
local fp = assert( io.open(misc.local_path() .. PATHSEP .. "all_requires.lua", "rb") )
local require_str = ''
for line in fp:lines() do
  require_str = require_str .. '\n' .. line
end
core.log(require_str)
fp:close()
    
-------------------------------------------------------------------------------
-- commands
-------------------------------------------------------------------------------

misc.exec_history = {}
misc.exec_text = ''


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
  
  ["core:test"] = function()
  end,
  
  -- after some thoughts this was even more useful
  --  ( I mean you do need to `require` a lot of stuff.. )
  ["core:exec-file"] = function()
    assert(load(table.concat(doc().lines)))()
  end,
  
  ["core:exec-input"] = function()
    core.command_view:set_text(misc.exec_text)
    core.command_view:enter("Exec", function(text, item)
      core.log("%s", misc.str(assert(load(require_str .. "\n\nreturn "..text))()))
      if (item == nil) or (text ~= item.text) then
        table.insert(misc.exec_history, text)
      end
    end, function(text)
      return common.fuzzy_match(misc.exec_history, text)
    end)
    misc.exec_text = ''
  end,
  
  ["core:exec-input-and-insert"] = function()
    core.command_view:enter("Exec and insert at cursor", function(text)
      local s = assert(load(require_str .. "\n\nreturn "..text))()
      core.log('%s', s)
      local line,col = core.active_view.doc:get_selection()
      core.active_view.doc:insert(line, col, misc.str(s))
    end)
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

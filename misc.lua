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
local StatusView = require "core.statusview"
local LogView = require "core.docview"
local Doc = require "core.doc"
local CommandView = require "core.commandview"
local RootView = require "core.rootview"
local style = require "core.style"
local config = require "core.config"
local common = require "core.common"
local translate = require "core.doc.translate"

-- I mean. Why are these not exposed??
local Node = getmetatable(core.root_view.root_node)
local EmptyView = getmetatable(core.active_view)

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
-- Lite compatibility                                                        --
-------------------------------------------------------------------------------

local USERDIR = rawget(_G,'USERDIR')

if USERDIR == nil then
  core.log("Lite compatibility..")
  USERDIR = EXEDIR .. PATHSEP .. 'user' -- debug.getinfo(1).source:match("@?(.*/)")
  keymap.add_direct = keymap.add_direct or keymap.add
  
  core.project_dir = core.project_dir or os.getenv("PWD") or io.popen("cd"):read()
  core.project_directories = core.project_directories or {{name=core.project_dir}}
  core.normalize_to_project_dir = core.normalize_to_project_dir or function(path)
    return path
  end
  common.home_expand = common.home_expand or function(a) return a end
  common.home_encode = common.home_encode or function(a) return a end
  common.home_encode_list = common.home_encode_list or function(a) return a end
  
  common.serialize = common.serialize or function(val)
    if type(val) == "string" then
      return string.format("%q", val)
    elseif type(val) == "table" then
      local t = {}
      for k, v in pairs(val) do
        table.insert(t, "[" .. common.serialize(k) .. "]=" .. common.serialize(v))
      end
      return "{" .. table.concat(t, ",") .. "}"
    end
    return tostring(val)
  end
  
  misc.core__quit__orig = core.quit
  
  core.quit = function()
    core.confirm_close_docs(core.docs, function() misc.core__quit__orig(true) end)
  end
  
  RootView.get_active_node_default = RootView.get_active_node_default or RootView.get_active_node

  Node.close_all_docviews = Node.close_all_docviews or function(self,keep_active)
    if self.type == "leaf" then
      local i = 1
      while i <= #self.views do
        local view = self.views[i]
        if view:is(DocView) 
           and not view:is(CommandView) 
           and not view:is(StatusView) 
           and not view:is(misc.EmptyView) 
           -- and (not keep_active or view ~= self.active_view) 
          then
          table.remove(self.views, i)
        else
          i = i + 1
        end
      end
      if #self.views == 0 and self.is_primary_node then
        self:add_view(EmptyView())
      end
    else
      self.a:close_all_docviews(keep_active)
      self.b:close_all_docviews(keep_active)
      if self.a:is_empty() and not self.a.is_primary_node then
        self:consume(self.b)
      elseif self.b:is_empty() and not self.b.is_primary_node then
        self:consume(self.a)
      end
    end
  end
  
  Node.is_empty = Node.is_empty or function (self)
    if self.type == "leaf" then
      return #self.views == 0 or (#self.views == 1 and self.views[1]:is(EmptyView))
    else
      return self.a:is_empty() and self.b:is_empty()
    end
  end

  RootView.close_all_docviews = RootView.close_all_docviews or function(self, keep_active)
    
  --   self.root_node:close_all_docviews(keep_active)
  -- end
  -- local function temp()
    -- close current window while it changes anything
    local nViews = 0
    while (core.root_view.root_node:nViews() ~= nViews) do
      nViews = core.root_view.root_node:nViews()
      if core.active_view.vibe_parent_node then
        core.active_view.vibe_parent_node:close()
      else 
        break
      end
    end

    -- self.root_node:close_all_docviews(keep_active)
  end
  
  core.set_project_dir = core.set_project_dir or function(new_dir, change_project_fn)
    local chdir_ok = pcall(system.chdir, new_dir)
    if chdir_ok then
      if change_project_fn then change_project_fn() end
      core.project_dir = core.project_dir or os.getenv("PWD") or io.popen("cd"):read()
      core.project_directories = core.project_directories or {{name=core.project_dir}}
      core.project_files = {}
      core.project_files_limit = false
      return true
    end
    return false
  end
  
  core.get_project_files = core.get_project_files or function()
    return coroutine.wrap(function()
      for _,f in ipairs(core.project_files) do
        coroutine.yield(core.project_dir, f)
      end
    end)
  end

end


misc.doc_abs_filename = function(doc)
  return doc and (doc.abs_filename or system.absolute_path(doc.filename))
end

-- misc.USERDIR = USERDIR

misc.USERDIR = rawget(_G,'USERDIR') or debug.getinfo(1).source:match("@?(.*/)")

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
core.vibe.clipboard_ring_max = 0
misc.system__set_clipboard = system.set_clipboard

function system.set_clipboard(s, skip_ring)
  core.log_quiet('vibe system system.set_clipboard')
  if s == nil then
    return
  end
  if core.vibe.flags['run_repeat_seq'] then
    core.log_quiet('  run_repeat_seq')
    if core.vibe.flags['run_repeat_seq__started_clipboard']==false then
      core.vibe.clipboard_ring_max = core.vibe.clipboard_ring_max + 1
      core.vibe.clipboard_ring[core.vibe.clipboard_ring_max]=''
    end
    core.vibe.flags['run_repeat_seq__started_clipboard'] = true
    -- accumulate repeated stuff
    core.vibe.clipboard_ring[core.vibe.clipboard_ring_max] =
        core.vibe.clipboard_ring[core.vibe.clipboard_ring_max] .. s
    core.vibe.clipboard_ring_ix = core.vibe.clipboard_ring_max
    core.vibe.clipboard_ring[core.vibe.clipboard_ring_max
                             - config.vibe.clipboard_ring_max] = nil
    misc.system__set_clipboard(core.vibe.clipboard_ring[core.vibe.clipboard_ring_max])
  else
    if skip_ring then
      core.log_quiet('  skip ring')
      core.log_quiet('  = %s', misc.str(skip_ring))
      -- pass
    else
      core.vibe.clipboard_ring_max = core.vibe.clipboard_ring_max + 1
      core.vibe.clipboard_ring[core.vibe.clipboard_ring_max] = s
      core.vibe.clipboard_ring_ix = core.vibe.clipboard_ring_max
      core.log_quiet('no skip, ix=%i', core.vibe.clipboard_ring_ix)
      core.vibe.clipboard_ring[core.vibe.clipboard_ring_max - config.vibe.clipboard_ring_max] = nil
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
-- Really global stuff
-------------------------------------------------------------------------------

-- so that get_dotsep('misc.exec_history') == core.vibe.misc.exec_history
function misc.get_dotsep(s, obj)
  core.log("get_dotsep, s=%s obj=%s", s, tostring(obj))
  if not obj then
    obj = core.vibe
  end
  local dotix = s:find_literal('.')
  if dotix then
    return misc.get_dotsep(s:sub(dotix+1), obj[s:sub(1,dotix-1)])
  else
    return obj[s]
  end
end

function misc.set_dotsep(s, v, obj)
  if obj == nil then
    obj = core.vibe
  end
  local dotix = s:find_literal('.')
  if dotix then
    misc.set_dotsep(s:sub(dotix+1), v, obj[s:sub(1,dotix-1)])
  else
    obj[s] = v
  end
end

function misc.is_fun(x)
  return type(x) == "function"
end

misc.is_function = misc.is_fun

function misc.is_table(x)
  return type(x) == "table"
end

function misc.is_string(x)
  return type(x) == "string"
end

function misc.tables_equal(test, ref, force_simmetrical)
  if force_simmetrical then
    return misc.compare_tables(test, ref) and misc.compare_tables(ref, test)
  else
    for key, value in pairs(ref) do
      if test[key] ~= value then
        return false
      end
    end
    return true
  end
end

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

assert('test'*2 == 'testtest')

function string:starts_with(prefix)
  return prefix and #self > #prefix and self:sub(1, #prefix)==prefix
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



function string:find_literal(substr, init)
  -- literal find, instead of pattern-based
  return string.find(self, substr, init or 1, true)
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

function string:is_command()
  return command.map[self]~=nil
end

function string:is_stroke_seq()
  -- well. 
  return not self:is_command()
end

function command.com_by_name(name)
  return command.map[name]
end


function command.com_is_runnable(com)
  return com and com.predicate()
end

function command.com_by_name_runnable(name)
  return command.com_is_runnable(command.com_by_name(name))
end

-- I'm pretty sure I've read too much of refactoring manuals.
function command.can_execute(com_str)
  -- which one is more readable?
  -- Try 0 (my old one):
    local com = command.map[com_str]
    -- nil => no such command => sequence?, if not, check predicate
    -- return com==nil or com.predicate() -- or misc.is_docview()
    return com and com.predicate() or misc.is_docview()
    -- (com==nil and misc.is_docview())
    --         or (com~=nil and com.predicate())
  -- try 1: <where everything's a function>
    -- return com_str:is_stroke_seq() or (com_str:is_command()
    --                                   and command.com_by_name_runnable(com_str))
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
  local rpath = path:gsub(PATHSEP..'[^'..PATHSEP..']+$','')
  -- gsub returns two values, discard the second one
  return rpath 
end

function misc.path_join(path, dir, ...)
  return dir and misc.path_join(path..PATHSEP..dir, ...) or path
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

function misc.table_join(a,...)
  if a == nil then
    return {}
  end
  local R = misc.copy(a)
  for a,b in pairs(misc.table_join(...)) do
    R[a] = b
  end
  return R
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

function table:find(value)
  for k,v in pairs(self) do
    if v == value then
      return k
    end
  end
  return nil
end

table.indexOf = table.find

function table:values()
  return misc.values(self)
end

function table:keys()
  return misc.keys(self)
end

function table:map(fun)
  local ret = {}
  for k,v in pairs(fun) do
    ret[k] = fun(v)
  end
  return ret
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

function misc.compare_fun(fun)
  return function(a,b) return fun(a)<fun(b) end
end

function misc.compare_key_fun(key)
  return function(a,b) return a[key]<b[key] end
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

function misc.literal_match_key(list, key, needle)
  local res = {}
  for _, item in ipairs(list) do
    if string.find_literal(item[key], needle) then
      table.insert(res, item)
    end
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
  -- core.log('misc.list_dir, path=%s',path)
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

-- https://stackoverflow.com/a/40195356/2624911
function misc.exists(path)
   local ok, err, code = os.rename(path, path)
   if not ok then
      if code == 13 then
         -- Permission denied, but it exists
         return true
      end
   end
   return ok, err
end

--- Check if a directory exists in this path
function misc.isdir(path)
   -- "/" works on both Unix and Windows
   return misc.exists(path.."/")
end

function misc.file_ext(filename)
  local ext = filename:gsub(".*%.","")
  return ext
end

function misc.file_touch(filepath)
  if misc.file_exists(filepath) then
    core.error("File exists!")
    return nil, "File "..filepath.." exists!"
  else
    local file, err = io.open(filepath, 'w')
    if err == nil then
      file:close()
      return true
    else
      return nil, err
    end
  end
end

function misc.filesize_str(size)
  local sfxs = {"B", "KB", "MB", "GB", "TB", "PB"}
  local exp = math.floor(math.log(size+1)/math.log(1024))
  if exp>#sfxs then exp = #sfxs end
  local v = size/math.pow(2, exp*10)

  local s = string.format('%.3f', v)

  local dot_ix = s:find_literal('.') or #s

  s = (dot_ix > 4) and (s:sub(1,dot_ix-1)) or (s:sub(1,4))

  if s:sub(#s,#s)=='.' then s = s:sub(1,#s-1) end

  return s .. ' ' .. sfxs[exp + 1]
end

-----------------------------------

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

function misc.draw_items(items, x, y, w, h, draw_fn)
  draw_fn = draw_fn or common.draw_text

  local font = style.font
  local color = style.text
  
  if type(items)=="string" then
    items = {items}
  end

  for _, item in ipairs(items) do
    if type(item) == "userdata" then
      font = item
    elseif type(item) == "table" then
      color = item
    else
      x = draw_fn(font, color, item, nil, x, y, w, h)
    end
  end

  return x
end

function misc.get_items_width(items)
  return misc.draw_items( items, 0, 0, 1e6, 1e6, misc.text_width )
end

-------------------------------------------------------------------------------
-- scratch

function misc.scratch_filepath()
  return misc.USERDIR .. PATHSEP .. "scratch.lua"
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

function misc.is_docview()
  return core.active_view:is(DocView)
end

local tablestr_depth = 0
local str_infighter = {} -- Infinity Fighter. you'll see.
local function str(a, cur_path, ignore_prefix)
  cur_path = cur_path or 'root'
  local prefix = ignore_prefix and '' or (' ' * tablestr_depth)
  tablestr_depth = tablestr_depth + 1
  local R = ''
  if type(a) == "table" or type(a) == "function" then
    if str_infighter[a] then
      return str_infighter[a]
    else
      str_infighter[a] = cur_path
    end
  end
  if type(a) == 'table' then
    if tablestr_depth > (config.vibe.misc_str_max_depth or 4) then
      R = '<'..tostring(a)..'>'
    else
      R = '{'
      local listN = 0
      local is_list = true
      for j,ja in pairs(a) do
        if type(j) ~= "number" then
          is_list = false
          break
        end
      end

      for j,ja in pairs(a) do
        listN = listN + 1
        if not is_list or listN <= config.vibe.misc_str_max_list then
          local s = '[' .. str(j, cur_path, true) .. ']'
          R = R .. '\n' .. prefix .. s .. ' = ' .. str(ja,cur_path..s) ..','
        end
      end
      if is_list and listN > config.vibe.misc_str_max_list then
        R = R .. '\n' .. prefix
            .. string.format("<%i more elements..>", listN - config.vibe.misc_str_max_list)
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

function misc.str(a, path)
  tablestr_depth = 0
  str_infighter = {}
  return str(a, path)
end

function misc.has_selection()
  return core.active_view:is(DocView) and core.active_view.doc:has_selection()
end

function misc.drop_selection()
  local line,col = doc():get_selection()
  doc():set_selection(line,col)
end

function misc.open_doc(abs_filename)
  core.root_view:open_doc(core.open_doc(abs_filename))
end

function misc.goto_mark(mark)
  -- mark = {abs_filename=..,line=..,col=..}
  if misc.doc_abs_filename(doc()) ~= mark.abs_filename then
    core.log('jumping to file %s', mark.abs_filename)
    misc.open_doc(mark.abs_filename)
  end
  doc():set_selection(mark.line, mark.col)
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
    if line==line2 and col==col2 then --line ~= line2 or col == col2 then
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
-- GLOBALS

core._G__newindex = getmetatable(_G).__newindex

local function disable_strict_global()
  getmetatable(_G).__newindex = nil
end

local function enable_strict_global()
  getmetatable(_G).__newindex = core._G__newindex
end

disable_strict_global()

function log(A)
  core.log("%s", misc.str(A))
end

enable_strict_global()

local noop = function() end


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
      -- I do like persistent and changeable globals.
      disable_strict_global()
      -- try with return first to print some value
      local F, err = load(require_str .. "\n\nreturn "..text)
      local var_name = text
      if err then
        core.log("return didnt work")
        -- try and guess the last assignment to display var's new value
        var_name = text:match("(%a[%a%d]*)%s*=[^\n]+$")
        F,err = load(
          require_str .. "\n\n" 
          .. text 
          .. "\nreturn " .. (var_name or '"done"')
        )
      end  
      -- save to history (regardless of load success)
      if (item == nil) or (text ~= item.text) then
        table.insert(misc.exec_history, text)
      end
      if F then
        core.log("%s", misc.str(F(), var_name))
      else
        core.error("%s",err)
      end
      -- aand restore strict
      enable_strict_global()
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
function core.confirm_close_docs(docs, close_fn, ...)
  local dirty_count = 0
  local dirty_name
  for _, doc in ipairs(docs or core.docs) do
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
function misc.command_match_sug(text, item)
  return item
        and item.text
        and (item.text:sub(1,math.min(#text,#item.text))
               == text:sub(1,math.min(#text,#item.text)))
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local node__add_view__orig = Node.add_view

function Node:add_view(view)
  node__add_view__orig(self,view)
  view.vibe_parent_node = self
end


function Node:close_all()
  if self.type=="leaf" then
    -- for _,v in ipairs(self.views) do
    --   self:close_view(nil,v)
    -- end
    self.views = {}
    self:add_view(EmptyView())
  else
    self.a:close_all()
    self.b:close_all()
  end
end

function Node:close()
  if self.type=="leaf" then
    -- for _,v in ipairs(self.views) do
    --   self:close_view(nil,v)
    -- end
    self.views = {}
    local view = EmptyView()
    self:add_view(view)
    self:close_active_view(core.root_view.root_node) --, view)
  else
    self.a:close()
    self.b:close()
  end
end

core.log('aAAA')
function Node:nViews()
  if self.type=="leaf" then
    return #self.views
  else
    return self.a:nViews() + self.b:nViews()
  end
end

misc.Node = Node
misc.EmptyView = EmptyView

command.add(nil, {
  ['core:window:close-all-files'] = function()
    core.active_view.vibe_parent_node:close_all()
  end,

  ['core:window-close'] = function()
    core.active_view.vibe_parent_node:close()
  end,
})

-------------------------------------------------------------------------------

misc.noop = function() end

-------------------------------------------------------------------------------
-- I like options to be set with explicit names, not numerous arguments
misc.command_view_enter = function(title, options)
  -- options={
  --  title="Enter: or such",
  --  init="initial command view value",
  --  submit
  --  suggest= either a list of all options or a function(text) return list end
  --  cancel
  --  validate
  -- }
  if options==nil then 
    options = title
  else
    options.title = title
  end
  
  if misc.is_table(options.suggest) and options.suggest[1] then
    if misc.is_string(options.suggest[1]) then
      options.suggest = table.map(options.suggest, function(text) return {text=text} end)
    end
    if misc.is_table(options.suggest[1]) and options.suggest[1].text then
      local list = options.suggest
      options.suggest = function(text)
        return misc.fuzzy_match_key(list, 'text', text)
      end
    else
      core.error("Wrong command view options.suggest : "..misc.str(options.suggest))
    end
  end
  core.command_view:set_text(options.init or "")
  core.command_view:enter(
    options.title or "Enter:", -- like.. what did you expect as default?
    options.submit or function(item, text) log({item=item, text=text}) end, --
    options.suggest or misc.noop,
    options.cancel or misc.noop,
    options.validate or function() return true end
  )
end

-------------------------------------------------------------------------------
misc.core__set_active_view__orig = core.set_active_view
function core.set_active_view(view)
  if core.active_view
     and view ~= core.active_view
     and core.active_view ~= misc.last_active_view
     and not (view:is(CommandView))
     and not (core.active_view:is(CommandView))
      then
    -- when it's CommandView, switching to it as to last is crazy
    misc.last_active_view = core.active_view
  end
  return misc.core__set_active_view__orig(view)
end


return misc

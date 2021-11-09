--[[
--
FileView, a View for minimalistic file browser in lite xl
--
dunno really why I do this. Probably because it's fun))
--

TODOs:

]]--
local core = require "core"
local command = require "core.command"
local common = require "core.common"
local keymap = require "core.keymap"
local style = require "core.style"
local translate = require "core.doc.translate"

local misc = require "plugins.lite-xl-vibe.misc"
  
local ResultsView = require "plugins.lite-xl-vibe.ResultsView"
  
local FileView = ResultsView:extend()

function FileView:save_info()
  return { path=self.path, history=self.history, history_cur_ix=self.history_cur_ix }
end

function FileView.load_info(info)
  return FileView(info.path, info.history, info.history_cur_ix)
end

function FileView:goto_path(path)
  local old_path = self.path
  -- go to new path
  self.path = path
  -- push history
  self.history_cur_ix = self.history_cur_ix + 1
  self.history[self.history_cur_ix] = self.path
  -- clear further history
  for j=self.history_cur_ix+1 , #self.history do
    self.history[j] = nil
  end
  self:fill_results()
  -- also - select previous path if it is in the list
  self:select_item({ abs_filename=old_path })
end

function FileView:new(path, history, history_cur_ix)
  self.module = "FileView"
  self.path = path or core.project_dir
  self.history = history or { path }
  self.history_cur_ix = history_cur_ix or 1
  
  FileView.super.new(self,{
    title="F|"..self.path,
    items_fun=function()
      local R = misc.list_dir(self.path)
      self.title = "F|"..self.path
      local items = {}
      -- dirs
      table.insert(items, {
        abs_filename = misc.path_up(self.path),
        type = "dir",
        filename = "..",
        draw_items = "  ..",
      })
      --
      for _, dir in ipairs(R.dirs) do
        dir.draw_items = {style.accent , style.icon_font, "d",style.code_font, " ", dir.filename}
        table.insert(items, dir)
      end
      -- files
      for _, file in ipairs(R.files) do
        file.draw_items = {style.accent , style.icon_font, "f",style.code_font, " ", file.filename}
        table.insert(items, file)
      end
      for _, item in ipairs(items) do
        item.search_text = (item.type=="dir" and "Dir" or "File" ) .. item.filename
        -- columns
        item.Name = item.draw_items
        item.Size = item.size and misc.filesize_str(item.size or 0) or ''
        item.Modified = item.modified and os.date("%Y-%m-%d %X %a", item.modified) or ''
        item.Ext = item.type=="dir" and "<dir>" or misc.file_ext(item.filename)
      end
      return items
    end, 
    
    on_click_fun=function(res)
      if res.type == "dir" then
        local dv = core.active_view
        dv:goto_path(res.abs_filename)
      else
        core.root_view:open_doc(core.open_doc(res.abs_filename))
      end
    end, 
    
    sort_funs={
      ['name'] = function(item)
        return item.type:sub(1,1)..item.search_text
      end,
      ['size'] = function(item)
        return item.size or 0
      end,
      ['modified'] = function(item)
        return item.modified or 0
      end,
      ['extension'] = function(item)
        return item.Ext or ''
      end
    },
    column_names={'Name','Size','Modified','Ext'}
  })
end

local function show_directory(path)
  local fv = FileView(path)
  core.root_view:get_active_node_default():add_view(fv)
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
  
command.add(nil, {
  ["vibe:open-file"] = function()
    local view = core.active_view
    if view.doc and (view.doc.abs_filename or view.doc.filename) then
      local dirname, filename = misc.doc_abs_filename(view.doc):match("(.*)[/\\](.+)$")
      if dirname then
        dirname = core.normalize_to_project_dir(dirname)
        local text = dirname == core.project_dir and "" or common.home_encode(dirname) .. PATHSEP
        core.command_view:set_text(text)
      end
    end
    core.command_view:enter("Open File/Dir", function(text)
      local filename = system.absolute_path(common.home_expand(text))
      filename = filename:gsub('([^:])\\$','%1') -- for some reason get_file_info fails with trailing slash
      local path_stat, err = system.get_file_info(filename)
      if err then
        core.error("Cannot open file %q: %q", text, err)
        -- TODO: make the damn file!
      elseif path_stat.type == 'dir' then
        -- that is where we come in
        show_directory(text)
      else
        core.root_view:open_doc(core.open_doc(filename))
      end
    end, function (text)
      return common.home_encode_list(common.path_suggest(common.home_expand(text)))
    end)
  end,
})

command.add(nil, {
  ["vibe:open-select-dir"] = function()
    -- fill items
    local items = {}
    local current_doc_path = nil
    -- And first - dir of the current file
    if core.active_view and core.active_view.doc then
      current_doc_path = misc.path_up(misc.doc_abs_filename(core.active_view.doc))
      table.insert(items, current_doc_path)
    end
    -- then all working dirs
    for _, dir in ipairs(core.project_directories) do
      if dir.name ~= current_doc_path then
        table.insert(items,dir.name)
      end
    end
    --
    if #items > 1 then
      ResultsView.new_and_add({
        title="Dir to open",
        items=items,
        on_click_fun=function(res)
          command.perform('root:close')
          show_directory(res.text)
        end
      })
    else
      show_directory(items[1])
    end
  end,
})

command.add(FileView, {
  ["vibe:fileview:go-back"] = function()
    local fv = core.active_view
    if fv.history_cur_ix == 1 then
      core.error("no records further back")
    else
      fv.history_cur_ix = fv.history_cur_ix - 1
      fv.path = fv.history[fv.history_cur_ix]
      fv:fill_results()    
    end
  end,
  
  ["vibe:fileview:go-forward"] = function()
    local fv = core.active_view
    if fv.history[fv.history_cur_ix+1] == nil then
      core.error("no records further forward")
    else
      fv.history_cur_ix = fv.history_cur_ix + 1
      fv.path = fv.history[fv.history_cur_ix]
      fv:fill_results()
    end
  end,

  ["vibe:fileview:go-up"] = function()
    local fv = core.active_view
    if (fv.path:find_literal(PATHSEP) == nil)
       and not misc.path_is_win_drive(fv.path) then
      core.error("Nowhere to go up")
    else
      fv:goto_path(misc.path_up(fv.path))
    end
  end,
  
  ["vibe:fileview:rename"] = function()
    local item = core.active_view:get_selected_item()
    
    misc.command_view_enter({
      title="Rename to:",
      init=item.filename,
      submit=function(text, item_)
        local new_abs_filename = misc.path_join(misc.path_up(item.abs_filename), text)
        os.rename(item.abs_filename, new_abs_filename)
        command.perform("vibe:results:refresh")
        core.active_view:select_item({ abs_filename = new_abs_filename })
      end,
      validate=function(text)
        local new_abs_filename = misc.path_join(misc.path_up(item.abs_filename), text)
        if item.filename~=text and misc.exists(new_abs_filename) then
          log(text.." already exists!")
          return false
        end
        return true
      end
    })
  end,
  
  ["vibe:fileview:delete-item"] = function()
    local item = core.active_view:get_selected_item()
    misc.command_view_modal({
      title="Really delete?",
      Yes = function()
        local ok, err
        if misc.isdir(item.abs_filename) then
          ok, err = system.rmdir(item.abs_filename)
          log(ok)
          log(err)
        else
          ok, err = os.remove(item.abs_filename)
        end
        if not ok then
          log("error while removing "..item.abs_filename)
          core.error(err)
        else
          command.perform("vibe:results:refresh")
        end
      end
    })
  end,
  
  ["vibe:fileview:create-file"] = function()
    local root_path = core.active_view.path
    misc.command_view_enter({
      title="File to create",
      submit=function(text)
        local path = misc.path_join(root_path, text)
        misc.file_touch(path)
        command.perform("vibe:results:refresh")
        core.active_view:select_item({ abs_filename=path })
      end,
      validate=function(text)
        if misc.file_exists(misc.path_join(root_path, text)) then
          core.error("File "..text.." exists!")
          return false
        end
        return true
      end
    })
  end,
  
  ["vibe:fileview:create-dir"] = function()
    local root_path = core.active_view.path
    misc.command_view_enter({
      title="Dir to create",
      submit=function(text)
        local path = misc.path_join(root_path, text)
        system.mkdir(path)
        command.perform("vibe:results:refresh")
        core.active_view:select_item({ abs_filename=path })
      end,
      validate=function(text)
        if misc.exists(misc.path_join(root_path, text)) then
          core.error("Dir "..text.." exists!")
          return false
        end
        return true
      end
    })
  end,
  
  ["vibe:fileview:add-current-dir-to-workspace"] = function()
    misc.command_view_modal({
      title = "Really Add Directory?",
      Yes = function()
        core.add_project_directory(system.absolute_path(core.active_view.path))
        -- TODO: add the name of directory to prioritize
        core.reschedule_project_scan()
      end
    })
  end,
})

keymap.add({
  ["backspace"] = "vibe:fileview:go-back",
  ["ctrl+up"] = "vibe:fileview:go-up",
  ["ctrl+left"] = "vibe:fileview:go-back",
  ["ctrl+right"] = "vibe:fileview:go-forward",
  ["ctrl+r"] = "vibe:fileview:rename",
  ["delete"] = "vibe:fileview:delete-item",
  ["ctrl+n"] = "vibe:fileview:create-file",
  ["ctrl+shift+n"] = "vibe:fileview:create-dir",
  ["ctrl+shift+a"] = "vibe:fileview:add-current-dir-to-workspace",
})

return FileView

--[[
--
FileView, a View for minimalistic file browser in lite xl
--
dunno really why I do this. Probably because it's fun))
--

TODOs:
- title (ResutlsView)
- Go UP
  - If C:\..\ , display all active drives
- file size display
  - sort
- file modification sort
- file extension sort (?)
--
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

function FileView:new(path)
  self.path = path or core.project_dir
  self.history = { path }
  self.history_cur_ix = 1
  FileView.super.new(self,"F|"..path, function()
    local R = misc.list_dir(self.path)
    local items = {}
    -- dirs
    table.insert(items, {
      abs_filename = misc.path_up(self.path),
      draw_items = {"  .."},
      filename = "..",
      type = "dir",
    })
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
    end
    core.log('show_dir : %i items',#items)
    return items
  end, function(res)
    if res.type == "dir" then
      local dv = core.active_view
      -- go to new path
      dv.path = res.abs_filename
      -- push history
      dv.history_cur_ix = dv.history_cur_ix + 1
      dv.history[dv.history_cur_ix] = dv.path
      -- clear further history
      for j=dv.history_cur_ix+1 , #dv.history do
        dv.history[j] = nil
      end
      dv:fill_results()
    else
      core.root_view:open_doc(core.open_doc(res.abs_filename))
    end
  end, function(item)
    return item.search_text
  end)
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
    if view.doc and view.doc.abs_filename then
      local dirname, filename = view.doc.abs_filename:match("(.*)[/\\](.+)$")
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
    -- first - dir of the current file
    if core.active_view and core.active_view.doc then
      items[misc.path_up(core.active_view.doc.abs_filename)] = 1
    end
    -- then all working dirs
    for _, dir in ipairs(core.project_directories) do
      items[dir.name] = 1
    end
    --
    items = misc.keys(items)
    if #items > 1 then
      local mv = ResultsView("Dir to open",function()
        local r = {}
        for _,path in ipairs(items) do
          table.insert(r,{ text=path })
        end
        return r
      end, function(res)
        command.perform('root:close')
        show_directory(res.text)
      end)
      core.root_view:get_active_node_default():add_view(mv)
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
    if fv.path:find_literal(PATHSEP) == nil then
      core.error("Nowhere to go up")
    else
      fv.history_cur_ix = fv.history_cur_ix + 1
      fv.path = misc.path_up(fv.path)
      fv:fill_results()    
    end
  end,
})

keymap.add({
  ["backspace"] = "vibe:fileview:go-back",
  ["ctrl+up"] = "vibe:fileview:go-up",
  ["ctrl+left"] = "vibe:fileview:go-back",
  ["ctrl+right"] = "vibe:fileview:go-forward",
})

return FileView

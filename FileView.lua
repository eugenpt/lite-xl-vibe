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
  self.path = path
  self.history = { path }
  self.history_cur_ix = 1
  FileView.super.new(self,"F|"..path, function()
    local R = misc.list_dir(self.path)
    local items = {}
    -- dirs
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
  end)
end

local function show_directory(path, _fv)
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
})

keymap.add({
  ["backspace"] = "vibe:fileview:go-back",
  ["ctrl+left"] = "vibe:fileview:go-back",
  ["ctrl+right"] = "vibe:fileview:go-forward",
})

return FileView

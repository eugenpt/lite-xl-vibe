local core = require "core"
local command = require "core.command"
local common = require "core.common"
local DocView = require "core.docview"
local LogView = require "core.logview"

local misc = require "plugins.lite-xl-vibe.misc"
local SavableView = require "plugins.lite-xl-vibe.SavableView"


core.log("lite-xl-vibe.vibeworkspace")
local vibeworkspace = {}
vibeworkspace.add_save = {
  ['misc.exec_history'] = {},
  ['marks'] = {},
  ['registers'] = {},
  ['clipboard_ring'] = {},
}
-- Oh yeah I just did that.
-- The above initialized is the sth sth I've come up with to save stuff.
-- It is a table 
--  each value is a table
--   if value has `save` key, 
--    use it as function to get sth serializeable
--   otherwise, 
--    use the key to the value as input for misc.get_dotsep
--      (which basically does misc.get_dotsep('misc.lala') == vibe.misc.lala )
--     and get serialized version of that to save to the workspace file
--   ~same for load


function vibeworkspace.workspace_files_for(project_dir)
  local basename = common.basename(project_dir)
  local workspace_dir = misc.USERDIR .. PATHSEP .. "ws"
  local info_wsdir = system.get_file_info(workspace_dir)
  if not info_wsdir then
    local ok, err = system.mkdir(workspace_dir)
    if not ok then
      error("cannot create workspace directory: \"" .. err .. "\"")
    end
  end
  return coroutine.wrap(function()
    local files = system.list_dir(workspace_dir) or {}
    local n = #basename
    for _, file in ipairs(files) do
      if file:sub(1, n) == basename then
        local id = tonumber(file:sub(n + 1):match("^-(%d+)$"))
        if id then
          coroutine.yield(workspace_dir .. PATHSEP .. file, id)
        end
      end
    end
  end)
end


function vibeworkspace.consume_workspace_file(project_dir)
  for filename, id in vibeworkspace.workspace_files_for(project_dir) do
    local load_f = loadfile(filename)
    local workspace = load_f and load_f()
    if workspace and workspace.path == project_dir then
      os.remove(filename)
      return workspace
    end
  end
end

function vibeworkspace.savepath()
  return misc.USERDIR .. PATHSEP .. "vibe-ws.lua"
end

function vibeworkspace.save_path()
  local fp = io.open(vibeworkspace.savepath(), "w")
  if fp then
    local node_text = common.serialize(save_node(root))
    local dir_text = common.serialize(save_directories())
    fp:write(string.format("return '%s'", vibeworkspace.abs_filename))
    fp:close()
  end
end

local temp = loadfile(vibeworkspace.savepath())
vibeworkspace.abs_filename = temp and temp()


function vibeworkspace.get_workspace_filename(project_dir)
  local id_list = {}
  for filename, id in vibeworkspace.workspace_files_for(project_dir) do
    id_list[id] = true
  end
  local id = 1
  while id_list[id] do
    id = id + 1
  end
  local basename = common.basename(project_dir)
  return USERDIR .. PATHSEP .. "ws" .. PATHSEP .. basename .. "-" .. tostring(id)
end


function vibeworkspace.has_no_locked_children(node)
  if node.locked then return false end
  if node.type == "leaf" then return true end
  return vibeworkspace.has_no_locked_children(node.a) and vibeworkspace.has_no_locked_children(node.b)
end


function vibeworkspace.get_unlocked_root(node)
  if node.type == "leaf" then
    return not node.locked and node
  end
  if vibeworkspace.has_no_locked_children(node) then
    return node
  end
  return vibeworkspace.get_unlocked_root(node.a) or vibeworkspace.get_unlocked_root(node.b)
end


function vibeworkspace.save_view(view)
  local mt = getmetatable(view)
  if mt == DocView then
    return {
      type = "doc",
      active = (core.active_view == view),
      filename = view.doc.filename,
      selection = { view.doc:get_selection() },
      scroll = { x = view.scroll.to.x, y = view.scroll.to.y },
      text = not view.doc.filename and view.doc:get_text(1, 1, math.huge, math.huge)
    }
  end
  if view.vibe_save then
    return view:vibe_save()
  end
  if mt == LogView then return end
  for name, mod in pairs(package.loaded) do
    if mod == mt then
      return {
        type = "view",
        active = (core.active_view == view),
        module = name
      }
    end
  end
end


function vibeworkspace.load_view(t)
  if t.type == "doc" then
    local dv
    if not t.filename then
      -- document not associated to a file
      dv = DocView(core.open_doc())
      if t.text then dv.doc:insert(1, 1, t.text) end
    else
      -- we have a filename, try to read the file
      local ok, doc = pcall(core.open_doc, t.filename)
      if ok then
        dv = DocView(doc)
      end
    end
    -- doc view "dv" can be nil here if the filename associated to the document
    -- cannot be read.
    if dv and dv.doc then
      dv.doc:set_selection(table.unpack(t.selection))
      dv.last_line, dv.last_col = dv.doc:get_selection()
      dv.scroll.x, dv.scroll.to.x = t.scroll.x, t.scroll.x
      dv.scroll.y, dv.scroll.to.y = t.scroll.y, t.scroll.y
    end
    return dv
  end
  if t.type == "vibe_savable" then
    -- or should it be loadable?)
    return require("plugins.lite-xl-vibe."..t.module).load_info(t.info)
  end
  return require(t.module)()
end


function vibeworkspace.save_node(node)
  local res = {}
  res.type = node.type
  if node.type == "leaf" then
    res.views = {}
    for _, view in ipairs(node.views) do
      local t = vibeworkspace.save_view(view)
      if t then
        table.insert(res.views, t)
        if node.active_view == view then
          res.active_view = #res.views
        end
      end
    end
  else
    res.divider = node.divider
    res.a = vibeworkspace.save_node(node.a)
    res.b = vibeworkspace.save_node(node.b)
  end
  return res
end


function vibeworkspace.load_node(node, t)
  if t.type == "leaf" then
    local res
    local active_view
    for i, v in ipairs(t.views) do
      local view = vibeworkspace.load_view(v)
      if view then
        if v.active then res = view end
        node:add_view(view)
        if t.active_view == i then
          active_view = view
        end
      end
    end
    if active_view then
      node:set_active_view(active_view)
    end
    return res
  else
    node:split(t.type == "hsplit" and "right" or "down")
    node.divider = t.divider
    local res1 = vibeworkspace.load_node(node.a, t.a)
    local res2 = vibeworkspace.load_node(node.b, t.b)
    return res1 or res2
  end
end


function vibeworkspace.save_directories()
  local project_dir = core.project_dir
  local dir_list = {}
  for i = 2, #core.project_directories do
    dir_list[#dir_list + 1] = common.relative_path(project_dir, core.project_directories[i].name)
  end
  return dir_list
end


function vibeworkspace.add_save_str()
  local add_save = {}
  for k,v in pairs(vibeworkspace.add_save) do
    local by_name = misc.get_dotsep(k)
    add_save[k] = v.save and v:save() or (by_name.save and by_name.save() or by_name)
  end
  return common.serialize(add_save)
end

function vibeworkspace.load_saved(add_saved)
  for k,v in pairs(add_saved) do
    if vibeworkspace.add_save[k] then
      local load = vibeworkspace.add_save[k].load or misc.get_dotsep(k).load
      if load then
        load(v)
      else
        misc.set_dotsep(k,v)
      end
    end
  end
end

function vibeworkspace.save_workspace(filename)
  local root = vibeworkspace.get_unlocked_root(core.root_view.root_node)
  local workspace_filename = filename or vibeworkspace.abs_filename
  local fp = io.open(workspace_filename, "w")
  if fp then
    local node_text = common.serialize(vibeworkspace.save_node(root))
    local dir_text = common.serialize(vibeworkspace.save_directories())
    local str = string.format("return { path = %q, documents = %s, directories = %s, add_saved= %s }\n"
                              , core.project_dir, node_text, dir_text, vibeworkspace.add_save_str())
    fp:write(str)
    fp:close()
    vibeworkspace.abs_filename = workspace_filename
    core.log("vibe.workspace saved to %s", workspace_filename)
    return str
  end
  return nil
end


function vibeworkspace.load_workspace(_workspace)
  local workspace = _workspace or vibeworkspace.consume_workspace_file(core.project_dir)
  if workspace then
    local root = vibeworkspace.get_unlocked_root(core.root_view.root_node)
    local active_view = vibeworkspace.load_node(root, workspace.documents)
    if active_view then
      core.set_active_view(active_view)
    end
    for i, dir_name in ipairs(workspace.directories) do
      core.add_project_directory(system.absolute_path(dir_name))
    end
  end
end

local Node = misc.Node -- getmetatable(core.root_view.root_node)

local node__close_all_docviews = Node.close_all_docviews or Node.close_all
core.log("Node = %s",misc.str(Node))
core.log("Node.close_all = %s",misc.str(Node.close_all))
core.log("node__close_all_docviews = %s",misc.str(node__close_all_docviews))
function Node:close_all_docviews(...)
  -- also remove all savable views
  --  not sure if this is really necessary..
  if self.type == "leaf" then
    local i = 1
    while i <= #self.views do
      local view = self.views[i]
      if view:is(SavableView) then
        table.remove(self.views, i)
      else
        i = i + 1
      end
    end
  end
  node__close_all_docviews(self,...)
end

function vibeworkspace.open_workspace_file(_filename)
  local filename = _filename or vibeworkspace.abs_filename
  local workspace = loadfile(filename)
  workspace = workspace and workspace()
  if workspace then
    core.root_view:close_all_docviews()
    core.set_project_dir(workspace.path)
    vibeworkspace.load_workspace(workspace)
    vibeworkspace.abs_filename = filename
    
    vibeworkspace.add_saved = workspace.add_saved
    if workspace.add_saved then
      vibeworkspace.load_saved(workspace.add_saved)
    end
  else
    core.error("cannot load workspace from %s", filename)
  end
end

-------------------------------------------------------------------------------
-- this doesn't work really.
local run = core.run
function core.run(...)
  core.vibe.core_run_run = true
  core.vibe.need_to_load_workspace = #core.docs == 0
  core.run = run
  run(...)
  
  core.log('/vibe core run')
  return temp
end

command.add_hook("vibe:after-startup", function()
  if core.vibe.need_to_load_workspace then
    core.log("trying to load vibe workspace")
    local temp = loadfile(vibeworkspace.savepath())
    vibeworkspace.abs_filename = temp and temp()
    core.log("abs_filename=%s", vibeworkspace.abs_filename)

    core.try(vibeworkspace.open_workspace_file)

  else
    core.log('nah, dont need to load workspace')
  end
end)

local on_quit_project = core.on_quit_project
function core.on_quit_project()
  if vibeworkspace.abs_filename then
    core.try(vibeworkspace.save_workspace)
  end
  on_quit_project()
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

command.add(nil,{
  ["vibe:workspace:save-workspace-as"] = function()
    core.command_view:set_text(core.normalize_to_project_dir(core.project_dir .. '.ws'))
    core.command_view:enter("Save Workspace As", function(filename)
      vibeworkspace.save_workspace(common.home_expand(filename))
    end, function (text)
      return common.home_encode_list(common.path_suggest(common.home_expand(text)))
    end)
  end,
  ["vibe:workspace:open-workspace-file"] = function()
    local view = core.active_view
    core.command_view:set_text(core.normalize_to_project_dir(core.project_dir .. '.ws'))
    core.command_view:enter("Open Workspace File", function(text)
      vibeworkspace.open_workspace_file(system.absolute_path(common.home_expand(text)))
    end, function (text)
      return common.home_encode_list(common.path_suggest(common.home_expand(text)))
    end, nil, function(text)
      vibeworkspace.open_workspace_file(common.home_expand(text))
    end)
  end,
})

command.add( function() return vibeworkspace.abs_filename end, {
  ["vibe:workspace:save-workspace"] = vibeworkspace.save_workspace,
})

core.log("/lite-xl-vibe.vibeworkspace")
return vibeworkspace

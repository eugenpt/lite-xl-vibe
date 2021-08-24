--[[

  ResultsView
  
  A generalized View for all sorts of results,
    similar to project-search one.

  Arguments for constructor:
  
  1. title - Shown in table
  
  2. items_fun - function returning list of items
                 each item must contain either 
                  draw_items, a list of text, font, colors
                  or
                 title and text fields to be shown 
                 (same to projectsearch's
                   filename/place and line text respectively)
                 receives no arguments
                 
                 if you would like to search through results,
                 for each item provide eitherm
                 search_text - a string to make fuzzy_match on
                 or
                 title and text (they will be combined for you)
                 
  3. on_click_fun - function executed on selection of an item,
                    receives the item as one and only argument

]]--

local core = require "core"
local command = require "core.command"
local common = require "core.common"
local keymap = require "core.keymap"
local style = require "core.style"

local misc = require "plugins.lite-xl-vibe.misc"
local SavableView = require "plugins.lite-xl-vibe.SavableView"
local ResultsView = SavableView:extend()

local function default_sort_fun(item)
  return (item.title or '')..(item.text or '')
end

function ResultsView:save_info()
  -- not really that helpful
  return { title=self.title }
end

function ResultsView.load_info(info)
  return nil -- ResultsView(info.title)
end

function ResultsView:new(title, items_fun, on_click_fun, sort_funs, draw_columns)
  ResultsView.super.new(self)
  self.module = "ResultsView"
  self.title = title
  self.scrollable = true
  self.brightness = 0
  self.items_fun = items_fun or function() return {} end
  self.on_click_fun = on_click_fun or function() end
  self.sort_funs = sort_funs
                    and (type(sort_funs)=='function' 
                         and { default=sort_funs } or sort_funs)
                    or { name=default_sort_fun }
  self.sort_mode = -1
  self.draw_columns = draw_columns or {'draw_items'}
  self:fill_results()
end

function ResultsView:fill_results()
  self.results_src = self.items_fun()
  local color = common.lerp(style.text, style.accent, self.brightness / 100)
  for _,item in pairs(self.results_src) do
    item.draw_items = item.draw_items or {
          style.font, style.dim, item.title or '',
          style.code_font, color, item.text or ''
      }
  end
  self:reset_search()
end

function ResultsView:reset_search()
  self.selected_idx = 1
  self.results = misc.copy(self.results_src)
  self.search_text = nil
end

function ResultsView:get_name()
  return self.title or 'Results??'
end

function ResultsView:refresh()
  self:fill_results()
end

function ResultsView:on_mouse_moved(mx, my, ...)
  ResultsView.super.on_mouse_moved(self, mx, my, ...)
  self.selected_idx = 0
  for i, item, x,y,w,h in self:each_visible_result() do
    if mx >= x and my >= y and mx < x + w and my < y + h then
      self.selected_idx = i
      break
    end
  end
end

function ResultsView:on_mouse_pressed(...)
  local caught = ResultsView.super.on_mouse_pressed(self, ...)
  if not caught then
    self:open_selected_result()
  end
end

function ResultsView:open_selected_result()
  local res = self.results[self.selected_idx]
  if not res then
    return
  end
  core.try(function()
    self.on_click_fun(res)
  end)
end

function ResultsView:update()
  self:move_towards("brightness", 0, 0.1)
  ResultsView.super.update(self)
end

function ResultsView:get_results_yoffset()
  return style.font:get_height() + style.padding.y * 3 + (#self.draw_columns > 1 and style.font:get_height()+style.padding.y or 0)
end

function ResultsView:get_line_height()
  return style.padding.y + style.font:get_height()
end

function ResultsView:get_scrollable_size()
  return self:get_results_yoffset() + #self.results * self:get_line_height()
end

function ResultsView:get_visible_results_range()
  local lh = self:get_line_height()
  local oy = self:get_results_yoffset()
  local min = math.max(1, math.floor((self.scroll.y - oy) / lh))
  return min, min + math.floor(self.size.y / lh) + 1
end

function ResultsView:each_visible_result()
  return coroutine.wrap(function()
    local lh = self:get_line_height()
    local x, y = self:get_content_offset()
    local min, max = self:get_visible_results_range()
    y = y + self:get_results_yoffset() + lh * (min - 1)
    for i = min, max do
      local item = self.results[i]
      if not item then break end
      coroutine.yield(i, item, x, y, self.size.x, lh)
      y = y + lh
    end
  end)
end

function ResultsView:scroll_to_make_selected_visible()
  local h = self:get_line_height()
  local y = self:get_results_yoffset() + h * (self.selected_idx - 1)
  self.scroll.to.y = math.min(self.scroll.to.y, y)
  self.scroll.to.y = math.max(self.scroll.to.y, y + h - self.size.y)
end

function ResultsView:draw_items(items, x, y, w, h, draw_fn)
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

function ResultsView:draw()
  self:draw_background(style.background)
  
  -- status
  local ox, oy = self:get_content_offset()
  local x, y = ox + style.padding.x, oy + style.padding.y
  local color = common.lerp(style.text, style.accent, self.brightness / 100)
  renderer.draw_text(style.font, 
                     (self.title or '')
                     .. ' | sort by '
                       .. misc.keys(self.sort_funs)[math.abs(self.sort_mode)]
                       .. (self.sort_mode < 0 and ' desc' or ' asc')
                     .. (self.search_text
                           and ' Sarching for: '..self.search_text..''
                           or ''), 
                     x, y, color)
  
  -- horizontal line
  local yoffset = self:get_results_yoffset()
  if #self.draw_columns>1 then
    yoffset = yoffset - style.font:get_height()
  end
  local cox,coy = self:get_content_offset()
  local x = ox + style.padding.x
  local w = self.size.x - style.padding.x * 2
  local h = style.divider_size
  local color = common.lerp(style.dim, style.text, self.brightness / 100)
  renderer.draw_rect(x, oy + yoffset - style.padding.y, w, h, color)
  
  local lh = style.font:get_height()
  local lw = style.font:get_width("  |  ")
  -- results
  local y1, y2 = self.position.y, self.position.y + self.size.y
  local start_x = style.padding.x
  local max_x = 0
  for _,col_name in ipairs(self.draw_columns) do
    start_x = max_x + lw
    if #self.draw_columns > 1 then
      -- column name on top
      self:draw_items(
        {style.dim, col_name}, 
        cox + start_x,
        yoffset + coy + style.divider_size,
        self.size.x,
        style.font:get_height(),
        common.draw_text
      )
    end
    for i, item, ox,y,w,h in self:each_visible_result() do
      x = ox + start_x
      local color = style.text
      if i == self.selected_idx then
        color = style.accent
        renderer.draw_rect(x, y, w, h, style.line_highlight)
      end
      
      self:draw_items(item[col_name], x, y, w, h, common.draw_text)
      -- I am not sure renderer.draw_text inside common.<> returns x
      x = self:draw_items(item[col_name], x, y, w, h, misc.text_width)
      if x - ox > max_x then
        max_x = x - ox
      end
    end
  end
  self:draw_scrollbar()
end

function ResultsView:next_sort_mode()
  self.sort_mode = self.sort_mode > 0 and -self.sort_mode or 1-self.sort_mode
  if self.sort_mode > #misc.keys(self.sort_funs) then
    self.sort_mode = 1
  end
end

function ResultsView:sort()
  table.sort(self.results, misc.compare_fun( 
                             self.sort_funs[
                               misc.keys(
                                 self.sort_funs
                               )[math.abs(self.sort_mode)]
                             ]
                           )
             )
  if self.sort_mode < 0 then
    self.results = misc.list_reverse(self.results)
  end
end


command.add(ResultsView, {
  ["vibe:results:select-previous"] = function()
    local view = core.active_view
    view.selected_idx = math.max(view.selected_idx - 1, 1)
    view:scroll_to_make_selected_visible()
  end,

  ["vibe:results:select-next"] = function()
    local view = core.active_view
    view.selected_idx = math.min(view.selected_idx + 1, #view.results)
    view:scroll_to_make_selected_visible()
  end,

  ["vibe:results:open-selected"] = function()
    core.active_view:open_selected_result()
  end,

  ["vibe:results:refresh"] = function()
    core.active_view:refresh()
  end,
  
  ["vibe:results:move-to-previous-page"] = function()
    local view = core.active_view
    view.scroll.to.y = view.scroll.to.y - view.size.y
    local min, max = view:get_visible_results_range()
    view.selected_idx = min >= 1 and min or 1
  end,
  
  ["vibe:results:move-to-next-page"] = function()
    local view = core.active_view
    view.scroll.to.y = view.scroll.to.y + view.size.y
    local min, max = view:get_visible_results_range()
    view.selected_idx = max <= #view.results and max or #view.results
  end,
  
  ["vibe:results:move-to-start-of-doc"] = function()
    local view = core.active_view
    view.selected_idx = 1
    view.scroll.to.y = 0
  end,
  
  ["vibe:results:move-to-end-of-doc"] = function()
    local view = core.active_view
    view.scroll.to.y = view:get_scrollable_size()
    view.selected_idx = #view.results
  end,
  
  ["vibe:results:search"] = function()
    -- prepare field for fuzzy search
    for _,item in ipairs(core.active_view.results) do
      item.search_text = item.search_text or 
                         ((item.title or '') .. ' '
                          .. (item.text or ''))
    end
    local resultsview = core.active_view
    core.active_view.selected_idx = 0

    core.command_view:enter("Search in list:", function(text)
      resultsview.selected_idx=1
      if #resultsview.results==1 then
        resultsview:open_selected_result()
      end
      -- if found then
      --   last_fn, last_text = search_fn, text
      --   previous_finds = {}
      --   push_previous_find(dv.doc, sel)
      -- else
      --   core.error("Couldn't find %q", text)
      --   dv.doc:set_selection(table.unpack(sel))
      --   dv:scroll_to_make_visible(sel[1], sel[2])
      -- end
  
    end, function(text)
      if text == '' then
        resultsview.results = resultsview.results_src
        resultsview:sort()
        resultsview:reset_search()
      else
        resultsview.search_text = text
        resultsview.results = misc.fuzzy_match_key(resultsview.results_src, 'search_text', text)
      end
    end, function(explicit)
      -- if explicit then
      --   dv.doc:set_selection(table.unpack(sel))
      --   dv:scroll_to_make_visible(sel[1], sel[2])
      -- end
    end)
  end,
  
  ["vibe:results:drop-search"] = function()
    core.active_view:reset_search()
  end,
  
  ["vibe:results:sort"] = function()
    core.active_view:next_sort_mode()
    core.active_view:sort()
  end,

  ["vibe:results:close"] = function()
    command.perform("root:close")
  end,
})

command.add_hook("vibe:escape", function()
    if core.active_view:is(ResultsView) then
      command.perform("vibe:results:drop-search")
    end
  end
)

-------------------------------------------------------------------------------

keymap.add {
  ["f5"]                 = "vibe:results:refresh",
  ["ctrl+shift+f"]       = "vibe:results:find",
  ["up"]                 = "vibe:results:select-previous",
  ["down"]               = "vibe:results:select-next",
  ["return"]             = "vibe:results:open-selected",
  ["pageup"]             = "vibe:results:move-to-previous-page",
  ["pagedown"]           = "vibe:results:move-to-next-page",
  ["ctrl+home"]          = "vibe:results:move-to-start-of-doc",
  ["ctrl+end"]           = "vibe:results:move-to-end-of-doc",
  ["home"]               = "vibe:results:move-to-start-of-doc",
  ["end"]                = "vibe:results:move-to-end-of-doc",
  ["ctrl+f"]             = "vibe:results:search",
  ["ctrl+s"]             = "vibe:results:sort",
  ["escape"]             = "vibe:results:drop-search",
  ["ctrl+q"]             = "vibe:results:close",
}

return ResultsView

--[[

  ResultsView
  
  A generalized View for all sorts of results,
    similar to project-search one.

  Arguments for constructor:
  
  1. title - Shown in table
  
  2. items_fun - function returning list of items
                 title and text fields are shown 
                 (same to projectsearch's
                   filename/place and line text respectively)
                 receives no arguments
                 
  3. on_click_fun - function executed on selection of an item,
                    receives the item as one and only argument

]]--

local core = require "core"
local command = require "core.command"
local common = require "core.common"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"

local misc = require "plugins.lite-xl-vibe.misc"
local ResultsView = View:extend()

function ResultsView:new(title, items_fun, on_click_fun)
  ResultsView.super.new(self)
  self.title = title
  self.scrollable = true
  self.brightness = 0
  self.items_fun = items_fun or function() return {} end
  self.on_click_fun = on_click_fun or function() end
  self:fill_results()
end

function ResultsView:fill_results()
  self.selected_idx = 0
  self.results_src = self.items_fun()
  self.results = misc.copy(self.results_src)
end

function ResultsView:get_name()
  return self.title
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
  return style.font:get_height() + style.padding.y * 3
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

function ResultsView:draw()
  self:draw_background(style.background)
  -- results
  local y1, y2 = self.position.y, self.position.y + self.size.y
  for i, item, x,y,w,h in self:each_visible_result() do
    local color = style.text
    if i == self.selected_idx then
      color = style.accent
      renderer.draw_rect(x, y, w, h, style.line_highlight)
    end
    x = x + style.padding.x
    x = common.draw_text(style.font, style.dim, item.title or '', "left", x, y, w, h)
    x = common.draw_text(style.code_font, color, item.text or '', "left", x, y, w, h)
  end
  self:draw_scrollbar()
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
  end,
  
  ["vibe:results:move-to-next-page"] = function()
    local view = core.active_view
    view.scroll.to.y = view.scroll.to.y + view.size.y
  end,
  
  ["vibe:results:move-to-start-of-doc"] = function()
    local view = core.active_view
    view.scroll.to.y = 0
  end,
  
  ["vibe:results:move-to-end-of-doc"] = function()
    local view = core.active_view
    view.scroll.to.y = view:get_scrollable_size()
  end,
  
  ["vibe:results:search"] = function()
    -- prepare field for fuzzy search
    for _,item in ipairs(core.active_view.results) do
      item.search_text = (item.title or '') .. ' '
                          .. (item.text or '')
    end
    local resultsview = core.active_view
    core.active_view.selected_idx = 0

    core.command_view:enter("Search in list:", function(text)
      if #resultsview.results==1 then
        resultsview.selected_idx=1
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
      resultsview.results = misc.fuzzy_match_key(resultsview.results_src, 'search_text', text)
    end, function(explicit)
      -- if explicit then
      --   dv.doc:set_selection(table.unpack(sel))
      --   dv:scroll_to_make_visible(sel[1], sel[2])
      -- end
    end)
  end,
})

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
}

return ResultsView

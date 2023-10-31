--[[

All things interface

]]
   --

local core = require "core"
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local StatusView = require "core.statusview"
local DocView = require "core.docview"
local View = require "core.view"

local com = require("plugins.lite-xl-vibe.com")
local misc = require "plugins.lite-xl-vibe.misc"

local status = {}


local function get_mode_str()
  return core.vibe and (core.vibe.mode == 'insert' and "INSERT" or "NORMAL") or 'nil?'
end


function StatusView:get_items()
  if getmetatable(core.active_view) == DocView then
    local dv = core.active_view
    local line, col = dv.doc:get_selection()
    local dirty = dv.doc:is_dirty()
    local indent = dv.doc.indent_info
    local indent_label = (indent and indent.type == "hard") and "tabs: " or "spaces: "
    local indent_size = indent and tostring(indent.size) .. (indent.confirmed and "" or "*") or "unknown"

    local line_perc_str = '???'
    pcall(function()
      line_perc_str = string.format("% 3d%%", line / #dv.doc.lines * 100)
    end)



    return {
      dirty and style.accent or style.text, style.icon_font, "f",
      style.code_font, style.text, self.separator2,
      style.accent, get_mode_str(), style.text, self.separator2,
      style.dim, style.font, style.text,
      dv.doc.filename and style.text or style.dim, dv.doc:get_name(),
      style.text, style.code_font,
      self.separator2,
      "L", string.format('% 4d', line), " :",
      col > config.line_limit and style.accent or style.text, string.format('% 3d', col), " C",
      style.text,
      " ", -- self.separator,
      line_perc_str,
      self.separator2,
      core.vibe.stroke_seq,
      self.separator2,
      (core.vibe.debug_str and (#core.vibe.debug_str > config.vibe.debug_str_max))
      and (core.vibe.debug_str:sub(1, math.floor(config.vibe.debug_str_max / 2))
        .. core.vibe.debug_str:sub(#core.vibe.debug_str - math.ceil(config.vibe.debug_str_max / 2)
        , #core.vibe.debug_str))
      or core.vibe.debug_str,
      (config.vibe.permanent_status_tooltip
        and self.separator2 .. config.vibe.permanent_status_tooltip or '')
    }, {
      style.dim, self.separator2, style.text, indent_label, indent_size,
      style.dim, self.separator2, style.text,
      -- style.icon_font, "g", -- why is this here anyway?
      style.font, style.dim, self.separator2, style.text,
      #dv.doc.lines, " lines",
      self.separator,
      style.code_font,
      dv.doc.crlf and "CRLF" or "  LF",
      style.text, ' |', string.format('#%3s', core.vibe.num_arg),
      style.text, '|', string.format("%7s", core.vibe.last_stroke),
    }
  end

  return {
    style.text, style.icon_font, "P",
    style.code_font, style.text, self.separator2,
    style.accent, get_mode_str(), style.text, self.separator2,
    style.dim, style.font, style.text,
    style.text,
    style.font,
    core.vibe.debug_str,
  }, {
    -- style.icon_font, "g",
    style.font, style.dim, self.separator2,
    style.text, self.separator2, #core.docs, " / ",
    #core.project_files, " files",
    style.code_font,
    style.text, ' |', string.format('#%3s', core.vibe.num_arg),
    style.text, '|', string.format("%7s", core.vibe.last_stroke),
  }
end

local function draw_items(self, items, x, y, draw_fn)
  local font = style.font
  local color = style.text
  for _, item in ipairs(items) do
    if type(item) == "userdata" then
      -- font = item
    elseif type(item) == "table" then
      -- color = item
    else
      x = draw_fn(font, color, item, nil, x, y, 0, self.size.y)
    end
  end

  return x
end


local function text_width(font, _, text, _, x)
  return x + font:get_width(text)
end


function StatusView:draw_items(items, right_align, yoffset)
  local x, y = self:get_content_offset()
  y = y + (yoffset or 0)
  if right_align then
    local w = draw_items(self, items, 0, 0, text_width)
    x = x + self.size.x - w - style.padding.x

    renderer.draw_rect(x, y, self.size.x, self.size.y + y % 1, style.background2)

    -- this return is what's changed
    draw_items(self, items, x, y, common.draw_text)
  else
    x = x + style.padding.x
    draw_items(self, items, x, y, common.draw_text)
  end
end

function StatusView:draw()
  self:draw_background(style.background2)

  if self.message then
    self:draw_items(self.message, false, self.size.y)
  end

  if self.tooltip_mode then
    self:draw_items(self.tooltip)
  else
    local left, right = self:get_items()
    self:draw_items(left)
    self:draw_items(right, true)
    self:draw_items(right, true, self.size.y) -- I mean, why not have it there
  end
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

status.caret_width__orig = style.caret_width

command.add_hook("vibe:switch-to-insert-mode", { function()
  style.caret_width = status.caret_width__orig
end })

command.add_hook("vibe:switch-to-normal-mode", { function()
  if core.active_view.get_font then
    style.caret_width = core.active_view:get_font():get_width(' ')
  end
end })

local DocView__update__orig = DocView.update
function DocView:update(...)
  style.caret_width = (core.vibe.mode == 'normal' and core.active_view.get_font)
      and core.active_view:get_font():get_width(' ')
      or status.caret_width__orig
  DocView__update__orig(self, ...)
end

core.log('interface loaded?')

-------------------------------------------------------------------------------
-- Empty View Hint
-------------------------------------------------------------------------------
-- -- this did not work
-- local Node = getmetatable(core.root_view.root_node)
-- local node = Node("leaf")
-- local EmptyView = getmetatable(node.views[1])
-- This, however, worked, yer it relies on active_view being an EmptyView. ..
local EmptyView = misc.EmptyView

local function draw_text(x, y, color)
  local th = style.big_font:get_height()
  local dh = 2 * th + style.padding.y * 2
  local x1, y1 = x, y + (dh - th) / 2
  x = renderer.draw_text(style.big_font, "Lite XL Vibe", x1, y1, color)
  renderer.draw_text(style.font, "version " .. VERSION, x1, y1 + th, color)
  x = x + style.padding.x
  renderer.draw_rect(x, y, math.ceil(1 * SCALE), dh, color)
  local lines = {
    { fmt = "%s to run a command",                                                                             cmd =
    "core:find-command" },
    { fmt = "%s to open a file from the project",                                                              cmd =
    "core:find-file" },
    { fmt = "%s to change project folder",                                                                     cmd =
    "core:change-project-folder" },
    { fmt = "%s to open a project folder",                                                                     cmd =
    "core:open-project-folder" },
    { text = " " },
    { text = "Ctrl+N/P selects next/previous of the suggestions" },
    { text = " " },
    { text = "you are in " .. get_mode_str() .. " mode now" },
    { text = "Escape / Ctrl+[ to enter NORMAL mode as in VIM" },
    { text = "while in NORMAL mode, use <i> to enter INSERT mode again" },
    { text = " " },
    { text = "Press Alt+h to show/scroll stroke suggestions" },
    { text = " " },
    { text = "A good place to start is to press " .. (core.vibe.mode == "normal" and "" or "<ESC>") .. "<space>" },
    { text = " .. and move the mouse a bit, to force drawing of the tooltip .." },
  }
  th = style.font:get_height()
  y = y + (dh - (th + style.padding.y) * #lines) / 2
  local w = 0
  for _, line in ipairs(lines) do
    local text = ""
    if line.cmd then
      if keymap.get_binding(line.cmd) then
        text = string.format(line.fmt, keymap.get_binding(line.cmd))
      else
        text = string.format(line.fmt, '--')
      end
    else
      text = line.text
    end
    w = math.max(w, renderer.draw_text(style.font, text, x + style.padding.x, y, color))
    y = y + th + style.padding.y
  end
  return w, dh
end


function EmptyView:draw()
  self:draw_background(style.background)
  local w, h = draw_text(0, 0, { 0, 0, 0, 0 })
  local x = self.position.x + math.max(style.padding.x, (self.size.x - w) / 2)
  local y = self.position.y + (self.size.y - h) / 2
  draw_text(x, y, style.dim)
end

-------------------------------------------------------------------------------

return status

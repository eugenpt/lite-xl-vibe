--[[

All things interface

]]--

local core = require "core"
local config = require "core.config"
local style = require "core.style"
local StatusView = require "core.statusview"
local DocView = require "core.docview"

local status = {}


function StatusView:get_items()
  if getmetatable(core.active_view) == DocView then
    local dv = core.active_view
    local line, col = dv.doc:get_selection()
    local dirty = dv.doc:is_dirty()
    local indent = dv.doc.indent_info
    local indent_label = (indent and indent.type == "hard") and "tabs: " or "spaces: "
    local indent_size = indent and tostring(indent.size) .. (indent.confirmed and "" or "*") or "unknown" 

    return {
      dirty and style.accent or style.text, style.icon_font, "f",
      style.code_font, style.text, self.separator2,
      style.accent, core.vibe:get_mode_str(), style.text, self.separator2,
      style.dim, style.font, style.text,
      dv.doc.filename and style.text or style.dim, dv.doc:get_name(),
      style.text, style.code_font,
      self.separator2,
      "L", string.format('% 4d',line), " :",
      col > config.line_limit and style.accent or style.text, string.format('% 3d',col), " C",
      style.text,
      " ", -- self.separator,
      string.format("% 3d%%", line / #dv.doc.lines * 100),
      self.separator2,
      core.vibe.debug_str,
    }, {
      style.text, indent_label, indent_size,
      style.dim, self.separator2, style.text,
      style.icon_font, "g",
      style.font, style.dim, self.separator2, style.text,
      #dv.doc.lines, " lines",
      self.separator,
      dv.doc.crlf and "CRLF" or "LF",
      style.text, self.separator2, core.vibe.last_stroke,
    }
  end

  return {
    style.text, 
    style.font,
    core.vibe.debug_str,
  }, {
    style.icon_font, "g",
    style.font, style.dim, self.separator2,
    #core.docs, style.text, " / ",
    #core.project_files, " files"
  }
end

status.draw_caret__orig = DocView.draw_caret
function DocView:draw_caret(x, y)
    local lh = self:get_line_height()
    renderer.draw_rect(x, y, 
      core.vibe.mode == 'insert'
        and style.caret_width*4
        or self:get_font():get_width(" "), -- monospace, right? 
      lh, style.caret
    )
end


return status

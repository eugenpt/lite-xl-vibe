--[[

All things interface

]]--

local core = require "core"
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local StatusView = require "core.statusview"
local DocView = require "core.docview"

local com = require("plugins.lite-xl-vibe.com")

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

    return {
      dirty and style.accent or style.text, style.icon_font, "f",
      style.code_font, style.text, self.separator2,
      style.accent, get_mode_str(), style.text, self.separator2,
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
      core.vibe.stroke_seq,
      self.separator2,
     (core.vibe.debug_str and (#core.vibe.debug_str > config.vibe.debug_str_max ))
        and (core.vibe.debug_str:sub(1, math.floor(config.vibe.debug_str_max/2))
              .. core.vibe.debug_str:sub(#core.vibe.debug_str - math.ceil(config.vibe.debug_str_max/2)
                                        ,#core.vibe.debug_str))
        or core.vibe.debug_str,
      (config.vibe.permanent_status_tooltip 
        and self.separator2 .. config.vibe.permanent_status_tooltip  or '')
    }, {
      style.text, indent_label, indent_size,
      style.dim, self.separator2, style.text,
      style.icon_font, "g",
      style.font, style.dim, self.separator2, style.text,
      #dv.doc.lines, " lines",
      self.separator,
      style.code_font,
      dv.doc.crlf and "CRLF" or "  LF",
      style.text, ' |', 
      
                  'h'.. (core.vibe.help and
                  (tostring(#core.vibe.help.stroke_seq_for_sug)
                  ..':'
                  ..tostring(#core.vibe.stroke_suggestions)
                  ..':'
                  ..tostring(#core.vibe.help.sug_strokes_sorted)
                  
                  ..':'
                  ..(core.vibe.help.is_time_to_show_sug() and '+' or '-')
                  ..':'
                  ..(core.vibe.flags['requesting_help_stroke_sugg'] and '+' or '-')
                  ) or '-'),
      style.text, '|', string.format('#% 3s',core.vibe.num_arg),
      style.text, '|', string.format("% 7s",core.vibe.last_stroke), 
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
  style.caret_width = (core.vibe.mode=='normal' and core.active_view.get_font)
                      and core.active_view:get_font():get_width(' ')
                      or status.caret_width__orig
  DocView__update__orig(self,...)
end


core.log('interface loaded?')

return status

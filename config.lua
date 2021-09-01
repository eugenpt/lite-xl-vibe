local config = require "core.config"

config.non_WORD_chars = " \t\n"

config.max_log_items = 1000

config.vibe = {}
config.vibe.clipboard_ring_max = 10
config.vibe.debug_str_max = 30

config.vibe.misc_str_max_depth = 8
config.vibe.misc_str_max_list = 4

config.vibe.max_stroke_sugg = 10
config.vibe.stroke_sug_delay = 0.500

-- set this to nil to stop showing. Or to sth else)
config.vibe.permanent_status_tooltip = "Alt-h for help and it's scroll. i to insert,   escape or ctrl+[ to normal"

-- max line difference to join jumplist events
config.vibe.history_max_dline_to_join = 5

-- max time difference to join jumplist events
config.vibe.history_max_dt_to_join = 0.5

-- max number of inline project search items to show
config.vibe.inline_search_maxN = 100

return config

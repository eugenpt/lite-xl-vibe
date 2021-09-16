warning: LF will be replaced by CRLF in visual_mode.lua.
The file will have its original line endings in your working directory
[1mdiff --git a/misc.lua b/misc.lua[m
[1mindex c048138..9fe5ce1 100644[m
[1m--- a/misc.lua[m
[1m+++ b/misc.lua[m
[36m@@ -297,6 +297,8 @@[m [mgetmetatable('string').__mul = function(s,n)[m
   end[m
 end[m
 [m
[32m+[m[32massert('test'*2 == 'testtest')[m
[32m+[m
 function string:isUpperCase()[m
   return self:upper()==self and self:lower()~=self[m
 end[m
[36m@@ -472,7 +474,6 @@[m [mfunction misc.list_drives()[m
       info.filename = path[m
       info.abs_filename = letters:sub(j,j)..':'[m
       table.insert(R.dirs, info)[m
[31m-[m
     end[m
   end[m
   return R[m
[36m@@ -622,11 +623,15 @@[m [mfunction misc.drop_selection()[m
   doc():set_selection(line,col)[m
 end[m
 [m
[32m+[m[32mfunction misc.open_doc(abs_filename)[m
[32m+[m[32m  core.root_view:open_doc(core.open_doc(abs_filename))[m
[32m+[m[32mend[m
[32m+[m
 function misc.goto_mark(mark)[m
   -- mark = {abs_filename=..,line=..,col=..}[m
   if misc.doc_abs_filename(doc()) ~= mark.abs_filename then[m
     core.log('jumping to file %s', mark.abs_filename)[m
[31m-    core.root_view:open_doc(core.open_doc(mark.abs_filename))[m
[32m+[m[32m    misc.open_doc(mark.abs_filename)[m
   end[m
   doc():set_selection(mark.line, mark.col)[m
 end[m
[1mdiff --git a/visual_mode.lua b/visual_mode.lua[m
[1mindex 97591fb..492e437 100644[m
[1m--- a/visual_mode.lua[m
[1m+++ b/visual_mode.lua[m
[36m@@ -28,19 +28,19 @@[m [mrequire "plugins.lite-xl-vibe.keymap"[m
 [m
 ----------------------------------------------------------------------------[m
 [m
[31m-local ts = 'doc:move-to-'[m
[31m-local ts2 = 'doc:select-to-'[m
[31m-local ts3 = 'doc:delete-to-'[m
[32m+[m[32mlocal doc_move_to = 'doc:move-to-'[m
[32m+[m[32mlocal doc_select_to = 'doc:select-to-'[m
[32m+[m[32mlocal doc_delete_to = 'doc:delete-to-'[m
 for bind,coms in pairs(keymap.nmap) do[m
[31m-  local com_name = misc.find_in_list(coms, function(item) return (item:sub(1,#ts)==ts) end)[m
[32m+[m[32m  local com_name = misc.find_in_list(coms, function(item) return (item:sub(1,#doc_move_to)==doc_move_to) end)[m
   if com_name then[m
     [m
[31m-    local verbose = com_name:find_literal('-word-')[m
[32m+[m[32m    local verbose = com_name:find_literal('-start-of-line')[m
     if verbose then[m
     core.log('[%s] -> %s', bind, misc.str(coms))[m
     end[m
     [m
[31m-    local sel_name = ts2..com_name:sub(#ts+1)[m
[32m+[m[32m    local sel_name = doc_select_to .. com_name:sub(#doc_move_to+1)[m
     [m
     if verbose then[m
       core.log('sel_name=[%s]',sel_name)[m

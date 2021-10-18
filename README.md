# lite-xl-vibe
VI(m?) Bindings (with a hint of Emacs) for [lite-xl](https://github.com/lite-xl/lite-xl) (but made mostly compatible with [lite](https://github.com/rxi/lite))

# Short demo:
![](intro.gif)

## Installation

For lite-xl just clone the repo as plugins subfolder
```
git clone git@github.com:eugenpt/lite-xl-vibe.git ~/.config/lite-xl/plugins/lite-xl-vibe
```

For lite, clone into plugins subfolder under lite installed path

```
git clone git@github.com:eugenpt/lite-xl-vibe.git <lite>/data/plugins/lite-xl-vibe
```


# Intro

If you don't know what VIM is, .. you really should. Also - how did you find this page??

If you do know what VIM is - this plugin provides basic support of VIM bindings.

Press `Esc`/`Ctrl+[` to go into `NORMAL` mode, to navigate, select, do whatever you want (except for actual input)

Press `i` while in `NORMAL` mode to go back to `INSERT` mode 
(works same as lite or almost any editor usually.
 Some differences are here from Emacs, see details [below](#differences-in-insert-mode "Differences in INSERT mode") )
 
# Features

- Help on keystrokes and combinations via `Alt-H`
- Interactive lua exec shell (command `"core:exec-input"` or `<space>;`) with online suggestions!

- (Book-)Marks, including named ones (`Space+Return`) and one-keystroke ones 
  (`m`+letter to set, `'`/`\``+letter to go to a mark, uppercase for global marks)
- Registers (one for each letter - you can copy to them and paste from them using `"`+letter as prefix for copy/paste command)
- Clipboard Ring (after paste press `Ctrl+y` to change pasted text to one copied previously)
- History of cursor positions (`<space>oj` to list all or `<space>sj` to search)
- navigation to previous/next word (`b`/`w`/`e`)/WORD (`W`/`B`)/block (`[`/`]`)
- deletion/selection(`d`/`v`/`c`) to previous/next word/.../mark
- deletion/selection/..(`d`/`v`/`c`) inside(`i`) word(`w`)/()/[]/block(`b`) 
  (so `vi(` to select inside matching parenthesis, `ciw` to change inside of word)
- macros (`q`+letter to start recording, `q` again to stop, `@`+letter to run)

- vim-like custom bindings to lite commands or to sequences of strokes (`keymap.add\_nmap({["strokes"]="command/sequence"}`)

- minimalistic File browser (`<space>od` to open one of project dirs or `<space>of` and type in any directory )

##### DOOM/Emacs thingies:
- `<space><return>` for (book-)marks
- `<space>.` for find-file
- `<space>,` for toogle between tabs with fuzzy search
- `<space>om` for list of all marks
- `<space>or` for list of all filled registers
- `<space>y` while sth is selected to yank to a named register (with select and search)
- `<space>p`/`<space>ir` to paste from register (with select and search)
- `<space>:` for commands
- `<space>;` for exec lua input (and show result in log and status)
- `<space>C-;` for exec lua input and insert results at cursor
- `<space>/` or `<space>sP` for fuzzy search in project
- `Alt+h` for help on furhter keystrokes/combinations


## Differences in INSERT mode

  Some of the Emacs bindings are mapped for insert mode by default, including:
- `Ctrl+e` moves cursor to end of the line
- `Ctrl+p` - the previous line
- `Ctrl+n` - the next line (to open new doc use `Ctrl+Shift+N`)
- `Ctrl+m` - same as `return`
- `Ctrl+/` opens `Fuzzy Find in Project`, for toggle comments press `Ctrl+x Ctrl+;`


## Usual process / the most common keystrokes

First - go to `NORMAL` mode by pressing `Esc`/`Ctrl+[`
( you may set `config.vibe_starting_mode = 'normal'` in your `.config/lite-xl/init.lua` )
- you'll see `NORMAL` in the bottom left corner of the screen.

To open a file, press `<space>.`, or `<space>of`.
( Navigation between suggestions via `Ctrl+n` / `Ctrl+p` )

Usually I open my editor in a folder I need it to be. 
If not, I usually do `<space>:` to search for commands, 
and then do `Add Directory` 
(you may only write `ad` and press `<return>`, the fuzzy matching will do the rest)
Then the `Add Directory:` prompt will show up, 
where you may enter any path and it will add the dir to your workspace.

Now speaking of workspaces, `vibe` does provide it's own workspaces, 
but sadly it's sort of difficult to load them on startup

Once you're done adding dirs to your workspace you may save the workspace using `<space>qS` shortcut 

(this reads as `press space, release, press q, release, press shift, press s, release`)
(you may load it later using `<space>qL`)


Once you want to do some actual editing, you'll need to select files to edit. 
The easiest way id to press `<space>od` 
, which will prompt you to select a directory to open if your workspace contains more than one
(navigate using arrows or `j`/`k`)
, and then `<return>` or `Ctrl+m`, or `C-m` in vim/vibe terms.

Once you select and open the directory, 
you'll see a minimalistic file browser opened there.

It has files, dirs, sizes, search, sortings, 
you may navigate , create files, dirs, rename files/ dirs/ and, surely, open files.

Navigation is using: 
- `j`/`k` for Down/Up, 
- `K` is for up-one-folder, 
- `H`/`L` is for going back/forward
- `gg`/`G` to go to top/bottom
- `+` is for creating files , `Ctrl+=` or `C-=` for creating dirs
- `s` to toggle sort mode, or `S` to select sort mode via command line
- `/` to search (only matching files will be shown, `<ESC>` to reset search)
- `<return>`/`Ctrl+m` for opening
- as always, `Alt-H` will show help on keystrokes

Once you open several files, you may wanna toggle between them

If you have several tabs opened, toggling between them goes with `Ctrl+j`/`Ctrl+k`. 
You may also press `<space>,` and type in filepath of the tab you want to get to.
If you simply want to open some file, you may press `<space>.` and type the filename for fuzzy match.

Navigation between suggestions uses `Ctrl+n` / `Ctrl+p` ,

If you want to split the view, you may do so vertically by `<space>wv` or `Ctrl+w w`
, horizontally - with `<space>ws` or `Ctrl+w s`

To toggle between views I prefer to use `Ctrl+h` / `Ctrl+l` 
(but usually I only split the view vertically once)

For other things you may want to edit your own keymaps

For example, I have the following in my `.config/lite-xl/init.lua`:
```
command.add(nil, {
  ["startup"] = function() core.vibe.workspace.open_workspace_file("<path to .ws file>") end,
})

config.user_nmap = {
  ["L"] = "startup",
  ["S"] = "vibe:workspace:save-workspace",
}

config.vibe_starting_mode = 'normal'

config.vibe_startup_strokes = '<ESC>L'

```

but it could've been just that:

```
config.vibe_after_startup = function()
  core.vibe.workspace.open_workspace_file("<path to .ws file>")
end  

```

The beauty of VI/VIM's normal mode navigation and editing is better kept to the VI/VIM themselves, 
google it and practice for a couple of weeks, 
to really get the editing with the speed of thought.

## Some random notes on the code/structure/dev-features

### Exec lua input

Press `<space>;` and start typing - you'll see interactive suggestions for lua input

Press `<space>C-;` (`Space` then `Ctrl+;`) and input sth like `23*6574` and press return.
You'll see `151202` typed where your cursor previously was. 
Neat, huh?

It does have a lot of bugs.

But interactive suggestions sort of work.
You may exec `vibe.test=123` and then when you input `vibe.te`, 
it will suggest you the `vibe.test` you've created, 
and if you select/input that, you'll see `123` being displayed via `core.log`. 
Globals are persistent as well.

### hooks

I do have hooks, they may be added to any command using `command.add_hook(com_name, hook)`, 
see the lines in `misc.lua` around `function command.add_hook`

But the simplest lite-xl-vibe-wide project search of `command.add_hook` will show I barely use it.

### visual mode

Those familiar with vim may notice that I don't really talk about visual mode here

That is mostly because I haven't really implemented it,
but in a way I did implement enough of it.

What I mean is - if you don't go into visual block (I don't have that), 
and forgive some discrepancy in vim line mode (I don'thave that either), 
you may see that whenever there is a selection, 
lite kinda works like vim in visual mode.

What I did may be seen in `visual_mode.lua`, 
basically, for every movement 
I added commands to select/delete/change to that movement 
whenever there is a selection (commands like `vibe:move-to...`)

(I know, I know, those should've been like `vibe:visual:move-to..` but hey)


### General

The whole `init.lua` is a mess, I intend on refactoring it, 
for now I am in a state where it kinda works 
and I'm just preparing myself by refactoring smaller pieces first.

## __

heavily inspired by and originally started from [modalediting of a327ex's lite-plugins](https://github.com/a327ex/lite-plugins)


Yes, I am aware of the vim-mode branch, but
- Really - lite and lite-xl openly state that any additional functionality thet can be added via plugin should be added in that manner and I sort of believe that it can be in this case
- X fingers crossed but I'd franko'ly choose my own way instead of the one that the core features are implemented in. (although I am afraid that is only because I haven't made those features myself yet and when I do, my own version would probably be soo damn unusable..)
- I really want to build sth like that myself





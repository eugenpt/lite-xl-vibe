# lite-xl-vibe
VI(m?) Bindings (with a hint of Emacs) for [lite-xl](https://github.com/lite-xl/lite-xl) (but made mostly compatible with [lite](https://github.com/rxi/lite))


## Installation

For lite-xl just clone the repo as plugins subfolder
```
git clone git@github.com:eugenpt/lite-xl-vibe.git ~/.config/lite-xl/plugins/lite-xl-vibe
```

For lite, clone into plugins subfilder under lite installed path

```
git clone git@github.com:eugenpt/lite-xl-vibe.git <lite>/data/plugins/lite-xl-vibe
```


# Intro

If you don't know what VIM is you really should. Also - how did you find this page??

If you do know that VIM is - this plugin provides basic support of VIM bindings.

Press `Esc`/`Ctrl+[` to go into `NORMAL` mode, to navigate, select, do whatever you want (except for actual input)

Press `i` while in `NORMAL` mode to go back to `INSERT` mode 
(works same as lite or almost any editor usually.
 Some differences are here from Emacs, see details [below](#differences-in-insert-mode "Differences in INSERT mode") )
 
# Features

- Help on keystrokes and combinations via `Alt-H`

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


heavily inspired by and originally started from [modalediting of a327ex's lite-plugins](https://github.com/a327ex/lite-plugins)


Yes, I am aware of the vim-mode branch, but
- Really - lite and lite-xl openly state that any additional functionality thet can be added via plugin should be added in that manner and I sort of believe that it can be in this case
- X fingers crossed but I'd franko'ly choose my own way instead of the one that the core features are implemented in. (although I am afraid that is only because I haven't made those features myself yet and when I do, my own version would probably be soo damn unusable..)
- I really want to build sth like that myself





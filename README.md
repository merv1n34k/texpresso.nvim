# TeXpresso.nvim

Neovim plugin for [TeXpresso](https://github.com/let-def/texpresso) — a live LaTeX previewer with real-time editing, SyncTeX synchronization, and quickfix diagnostics.

>[!IMPORTANT]
> This is a fork of [let-def/texpresso.vim](https://github.com/let-def/texpresso.vim). Changes will eventually be merged upstream.

**Requirements:** Neovim 0.10+ and [TeXpresso](https://github.com/let-def/texpresso) binary in your PATH.

## Installation

### With vim.pack (Neovim 0.12+)

Add to your `init.lua`:

```lua
vim.pack.add({
  'https://github.com/merv1n34k/texpresso.nvim',
})
```

### With Lazy.nvim

```lua
{
  'merv1n34k/texpresso.nvim',
}
```

### Manual installation

Clone [TeXpresso.nvim](https://github.com/merv1n34k/texpresso.nvim) and make sure it is in Neovim runtime path.
For instance:

```shell
cd ~/.config/nvim/pack/plugins/start
git clone https://github.com/merv1n34k/texpresso.nvim.git
```

## Usage

1. Open a `.tex` file and launch the viewer:
   `:TeXpresso <path/to/main.tex>` (e.g. `:TeXpresso %` if the current file is the root)
2. The viewer will preview the `.tex` file, track your cursor position,
   and reflect buffer changes in real-time.

## Configuration

### `texpresso_path`

Customize the path to the texpresso binary:

```lua
require('texpresso').texpresso_path = '/path/to/texpresso'
```

### API

```lua
local tp = require('texpresso')

tp.is_running()      -- Check if TeXpresso process is active
tp.stop()            -- Stop the TeXpresso process
tp.theme()           -- Sync Neovim colors to the viewer
tp.synctex_forward() -- Jump PDF to cursor position
tp.next_page()       -- Go to next page
tp.previous_page()   -- Go to previous page

-- Idle convergence (requires a texpresso build with the (rerun) command)
tp.rerun             -- send (rerun t) at launch so texpresso converges
                     -- TOC/refs after idle (latexmk-style). Default: false.
tp.rerun_toggle()    -- toggle convergence on/off at runtime
tp.rerun_once()      -- trigger a single on-demand convergence pass

-- Stream mode (requires a texpresso build with -stream)
tp.stream_mode       -- set to true before launch() to enable streaming
tp.prime_patterns    -- glob list used by prime() (default: tex/bib/cls/sty)
tp.push(path, data)  -- push arbitrary bytes into texpresso's VFS at `path`
                     -- binary content auto-routes via open-base64
tp.prime(dir)        -- proactively push all files matching prime_patterns
                     -- (defaults to the launched root document directory)
```

### Stream mode

When `stream_mode = true`, the plugin launches texpresso with `-stream`.
The engine starts paused; the plugin registers attached buffers, primes
the VFS, then sends `resume` to begin rendering. Further bulk pushes
(e.g. `prime()`) are framed with `pause`/`resume` for an atomic snapshot.
`lookup-file` notifications are answered by pushing buffer content (or
disk fallback). This decouples "what the editor sees" from "what
texpresso sees": arbitrary bytes can be pushed to arbitrary virtual paths.

```lua
-- Buffer-driven: open .tex files, prime the project upfront
local tp = require('texpresso')
tp.stream_mode = true
tp.launch({ 'main.tex' })
tp.prime() -- push every *.tex/*.bib/*.cls/*.sty under main.tex's directory
```

```lua
-- Preprocessor-driven: synthesize TeX in-memory from any markup
local tp = require('texpresso')
tp.stream_mode = true
tp.launch({ '/virtual/document.tex' })

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
  buffer = md_buf,
  callback = function()
    local lines = vim.api.nvim_buf_get_lines(md_buf, 0, -1, false)
    local tex = my_md_to_tex(table.concat(lines, '\n'))
    tp.push('/virtual/document.tex', tex)
  end,
})
```

### Debug logging

```lua
require('texpresso').logger = function(msg)
  print(msg)
end
```

## Roadmap

- [ ] Resolve quickfix filenames to absolute paths ([#1](https://github.com/let-def/texpresso.vim/issues/1))
- [ ] Investigate auto-rendering not triggering on buffer change ([#5](https://github.com/let-def/texpresso.vim/issues/5))
- [ ] Allow customization: cursor sync, keybindings, stay-on-top
- [ ] Handle unknown incoming message types

## Screenshots

Launching TeXpresso in vim:

https://github.com/let-def/texpresso.vim/assets/1048096/b6a1966a-52ca-4e2e-bf33-e83b6af851d8

Live update during edition:

https://github.com/let-def/texpresso.vim/assets/1048096/cfdff380-992f-4732-a1fa-f05584930610

Using Quickfix window to fix errors and warnings interactively:

https://github.com/let-def/texpresso.vim/assets/1048096/e07221a9-85b1-44f3-a904-b4f7d6bcdb9b

Synchronization from Document to Editor (SyncTeX backward):

https://github.com/let-def/texpresso.vim/assets/1048096/f69b1508-a069-4003-9578-662d9e790ff9

Synchronization from Editor to Document (SyncTeX forward):

https://github.com/let-def/texpresso.vim/assets/1048096/78560d20-391e-490e-ad76-c8cce1004ce5

Theming, Light/Dark modes: 😎

https://github.com/let-def/texpresso.vim/assets/1048096/a072181b-82d3-42df-9683-7285ed1b32fc

# TODO

## Bugs
- [ ] Fix command injection in `synctex_backward` — file paths with spaces/special chars break `vim.cmd` string concatenation
- [ ] Fix `format_fix` greedy regex — `(.*):(%d*):` misparsed filenames with colons; `%d*` matches zero digits
- [ ] Fix `ftplugin/tex.lua` calling `attach()` before launch — sends are silently dropped, root cause of #8
- [ ] Reset `M.log`/`M.fix`/`M.fixcursor` on `M.launch` restart — stale diagnostics persist across sessions
- [ ] Handle `vim.system` spawn failure — no user feedback if binary not found

## Improvements
- [ ] Early-return in `synctex_forward_hook` when process not running — runs on every `CursorMoved` unnecessarily
- [ ] Simplify `M.attach(...)` varargs to `M.attach(buf)` direct parameter
- [ ] Cache `getqfid()` result in `setqf` — currently called twice per invocation
- [ ] Use `vim.notify()` instead of `print()` for user-facing messages
- [ ] Use bit operations (`bit.rshift`/`bit.band`) in `format_color` instead of `math.fmod`/`math.floor`
- [ ] Avoid mutating input `lines` table in `buffer_append`
- [ ] Improve log buffer lifecycle — use `BufDelete` autocmd instead of scanning all buffers

## Upstream Issues
- [ ] Fix included files not updating preview on edit (#8)
- [ ] Resolve quickfix filenames to absolute paths (#1)
- [ ] Investigate auto-rendering not triggering on buffer change (#5)
- [ ] Windows/WSL support (#7)

## Backlog
- [ ] Handle unknown incoming message types
- [ ] Allow customization: cursor sync, keybindings, stay-on-top
- [ ] Update README: bump requirements to Neovim 0.10+, add vim.pack install instructions

## Done
- [x] Core JSON protocol implementation
- [x] SyncTeX forward/backward synchronization
- [x] Quickfix integration for diagnostics
- [x] Theme synchronization (light/dark)
- [x] Customizable texpresso binary path
- [x] Argument caching for `:TeXpresso`
- [x] Skip Overfull/Underfull warnings
- [x] Handle invalid protocol input
- [x] Lazy.nvim installation docs
- [x] Fix `local let args` syntax oddity
- [x] Add `local` to `cmd` variable in `M.launch`
- [x] Replace deprecated `nvim_get_hl_by_name` with `nvim_get_hl`
- [x] Fix nil crash in `format_fix` when regex doesn't match
- [x] Add `M.is_running()` and `M.stop()` public API
- [x] Migrate from `vim.fn.jobstart` to `vim.system`
- [x] Add stylua config and format codebase

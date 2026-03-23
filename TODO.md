# TODO

## Upstream Issues
- [x] Fix included files not updating preview on edit (#8)
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
- [x] Fix command injection in `synctex_backward`
- [x] Fix `format_fix` greedy regex
- [x] Track attached buffers and sync on launch (#8)
- [x] Reset diagnostics and log state on launch restart
- [x] Handle `vim.system` spawn failure gracefully
- [x] Early-return in `synctex_forward_hook` when process not running
- [x] Simplify `M.attach(...)` varargs to `M.attach(buf)`
- [x] Cache `getqfid()` result in `setqf`
- [x] Use `vim.notify()` instead of `print()`
- [x] Use bit operations in `format_color`
- [x] Avoid mutating input table in `buffer_append`
- [x] Improve log buffer lifecycle with `BufDelete` autocmd

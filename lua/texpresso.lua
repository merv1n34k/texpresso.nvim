local M = {}

-- Configuration

M.texpresso_path = 'texpresso'

-- Logging routines

-- Debug logging function, silent by default
-- Change this variable to redirect the debug log.
-- E.g. require('texpresso').logger = foo
M.logger = nil

-- Cache last arguments passed to TeXpresso
M.last_args = {}

-- Debug printing function
-- It uses vim.inspect to pretty-print and vim.schedule
-- to delay printing when vim is textlocked.
local function p(...)
  if M.logger then
    local args = { ... }
    if #args == 1 then
      args = args[1]
    end
    local text = vim.inspect(args)
    vim.schedule(function()
      M.logger(text)
    end)
  end
end

-- ID of the buffer storing TeXpresso log
local log_buffer_id = nil

-- Get the ID of the logging buffer, creating it if it does not exist.
local function log_buffer()
  if log_buffer_id and vim.api.nvim_buf_is_valid(log_buffer_id) then
    return log_buffer_id
  end
  log_buffer_id = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(log_buffer_id, 'texpresso-log')
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = log_buffer_id,
    callback = function()
      log_buffer_id = nil
    end,
  })
  return log_buffer_id
end

-- Append an array of lines to a buffer
-- The first entry is appended to the last line, other entries introduce new
-- lines.
local function buffer_append(buf, lines)
  local last = vim.api.nvim_buf_get_lines(buf, -2, -1, false)
  local merged = { last[1] .. lines[1] }
  for i = 2, #lines do
    merged[i] = lines[i]
  end
  vim.api.nvim_buf_set_lines(buf, -2, -1, false, merged)
end

-- Get buffer lines as a single string,
-- suitable for serialization to TeXpresso.
local function buffer_get_lines(buf, first, last)
  if first == last then
    return ''
  else
    return table.concat(vim.api.nvim_buf_get_lines(buf, first, last, false), '\n') .. '\n'
  end
end

-- Format a color VIM color to a TeXpresso color.
-- VIM represents a color as a single integer, encoding it as 0xRRGGBB.
-- RR, GG, BB are 8-bit unsigned integers.
-- TeXpresso represents a color as triple (R, G, B).
-- R, G, B are floating points in the 0.0 .. 1.0 range.
local function format_color(c)
  local r = bit.rshift(c, 16) / 255
  local g = bit.band(bit.rshift(c, 8), 0xFF) / 255
  local b = bit.band(c, 0xFF) / 255
  return { r, g, b }
end

-- Tell VIM to display file:line
local skip_synctex = false
local function synctex_backward(file, line)
  skip_synctex = true
  local escaped = vim.fn.fnameescape(file)
  local ok = pcall(vim.cmd.buffer, escaped)
  if not ok then
    vim.cmd.edit(escaped)
  end
  pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
end

-- Manage quickfix list

-- Allocate and reuse a quickfix id
local qfid = -1
local function getqfid()
  local id = vim.fn.getqflist({ id = qfid }).id
  if id > 0 then
    return id
  end
  vim.fn.setqflist({}, ' ', { title = 'TeXpresso' })
  qfid = vim.fn.getqflist({ id = 0 }).id
  return qfid
end

-- Set quickfix items
local function setqf(items)
  local id = getqfid()
  local idx = vim.fn.getqflist({ id = id, idx = 0 }).idx
  vim.fn.setqflist({}, 'r', { id = id, items = items, idx = idx })
end

-- Parse a Tectonic diagnostic line to quickfix format
local function format_fix(line)
  local typ, f, l, txt
  typ, f, l, txt = string.match(line, '([a-z]+): (.-):(%d+): (.*)')
  if not typ then
    return { text = line }
  elseif string.match(txt, '^Overfull') or string.match(txt, '^Underfull') then
    return {}
  else
    return { type = typ, filename = f, lnum = l, text = txt }
  end
end

-- TeXpresso process internal state
local job = {
  queued = nil,
  process = nil,
  generation = {},
  attached = {},
}

-- Log output from TeX
M.log = {}

-- Problems (warnings and errors) emitted by TeX
M.fix = {}
M.fixcursor = 0

local function shrink(tbl, count)
  for _ = count, #tbl - 1 do
    table.remove(tbl)
  end
end

local function expand(tbl, count, default)
  for i = #tbl + 1, count do
    table.insert(tbl, i, default)
  end
end

-- Internal functions to communicate with TeXpresso

-- Process a message received from TeXpresso
local function process_message(json)
  -- p(json)
  local msg = json[1]
  if msg == 'reset-sync' then
    job.generation = {}
  elseif msg == 'synctex' then
    vim.schedule(function()
      synctex_backward(json[2], json[3])
    end)
  elseif msg == 'truncate-lines' then
    local name = json[2]
    local count = json[3]
    if name == 'log' then
      shrink(M.log, count)
      expand(M.log, count, '')
    elseif name == 'out' then
      expand(M.fix, count, {})
      M.fixcursor = count
    end
  elseif msg == 'append-lines' then
    local name = json[2]
    if name == 'log' then
      for i = 3, #json do
        table.insert(M.log, json[i])
      end
    elseif name == 'out' then
      for i = 3, #json do
        local cursor = M.fixcursor + 1
        M.fixcursor = cursor
        M.fix[cursor] = format_fix(json[i])
      end
      vim.schedule(function()
        setqf(M.fix)
      end)
    end
  elseif msg == 'flush' then
    shrink(M.fix, M.fixcursor)
    vim.schedule(function()
      setqf(M.fix)
    end)
  end
end

-- Send a command to TeXpresso
function M.send(...)
  local text = vim.json.encode({ ... })
  if job.process then
    job.process:write(text .. '\n')
  end
  -- p(text)
end

-- Reload buffer in TeXpresso
function M.reload(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  M.send('open', path, buffer_get_lines(buf, 0, -1))
end

-- Communicate changed lines
function M.change_lines(buf, index, count, last)
  -- p("on_lines " .. vim.inspect{buf, index, index + count, last})
  local path = vim.api.nvim_buf_get_name(buf)
  local lines = buffer_get_lines(buf, index, last)
  M.send('change-lines', path, index, count, lines)
end

-- Attach a hook to synchronize a buffer
function M.attach(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if job.attached[buf] then
    return
  end
  job.attached[buf] = true

  if job.process then
    M.reload(buf)
  end

  local generation = job.generation
  vim.api.nvim_buf_attach(buf, false, {
    on_detach = function(_detach, buf)
      job.attached[buf] = nil
      M.send('close', vim.api.nvim_buf_get_name(buf))
    end,
    on_reload = function(_reload, buf)
      M.reload(buf)
      generation = job.generation
    end,
    on_lines = function(_lines, buf, _tick, first, oldlast, newlast, _bytes)
      if not job.process then
        return
      end
      if generation == job.generation then
        M.change_lines(buf, first, oldlast - first, newlast)
      else
        M.reload(buf)
        generation = job.generation
      end
    end,
  })
end

-- Public API

-- Use VIM theme in TeXpresso
function M.theme()
  local colors = vim.api.nvim_get_hl(0, { name = 'Normal' })
  if colors.bg and colors.fg then
    M.send('theme', format_color(colors.bg), format_color(colors.fg))
  end
end

-- Check if TeXpresso process is running
function M.is_running()
  return job.process ~= nil
end

-- Stop the TeXpresso process
function M.stop()
  if job.process then
    job.process:kill()
    job.process = nil
  end
end

-- Go to next page
function M.next_page()
  M.send('next-page')
end

-- Go to previous page
function M.previous_page()
  M.send('previous-page')
end

-- Go to the page under the cursor
function M.synctex_forward()
  local line, _col = unpack(vim.api.nvim_win_get_cursor(0))
  local file = vim.api.nvim_buf_get_name(0)
  M.send('synctex-forward', file, line)
end

local last_line = -1
local last_file = ''

function M.synctex_forward_hook()
  if not job.process then
    return
  end
  if skip_synctex then
    skip_synctex = false
    return
  end

  local line, _col = unpack(vim.api.nvim_win_get_cursor(0))
  local file = vim.api.nvim_buf_get_name(0)
  if last_line == line and last_file == file then
    return
  end
  last_line = line
  last_file = file
  M.send('synctex-forward', file, line)
end

-- Start a new TeXpresso viewer
function M.launch(args)
  if job.process then
    job.process:kill()
  end
  M.log = {}
  M.fix = {}
  M.fixcursor = 0
  setqf({})
  local cmd = { M.texpresso_path, '-json', '-lines' }

  if #args == 0 then
    args = M.last_args
  else
    M.last_args = args
  end
  if #args == 0 then
    vim.notify(
      'TeXpresso: no root file specified, use e.g. :TeXpresso main.tex',
      vim.log.levels.WARN
    )
    return
  end

  for _, arg in ipairs(args) do
    table.insert(cmd, arg)
  end
  job.queued = ''
  local ok, proc = pcall(vim.system, cmd, {
    stdin = true,
    stdout = function(err, data)
      if not data then
        return
      end
      local lines = vim.split(data, '\n', { plain = true })
      if job.queued then
        lines[1] = job.queued .. lines[1]
      end
      job.queued = table.remove(lines)
      for _, line in ipairs(lines) do
        if line ~= '' then
          local decode_ok, val = pcall(function()
            process_message(vim.json.decode(line))
          end)
          if not decode_ok then
            p('error while processing input', line, val)
          end
        end
      end
    end,
    stderr = function(err, data)
      if not data then
        return
      end
      vim.schedule(function()
        local buf = log_buffer()
        local lines = vim.split(data, '\n', { plain = true })
        buffer_append(buf, lines)
        if vim.api.nvim_buf_line_count(buf) > 8000 then
          vim.api.nvim_buf_set_lines(buf, 0, -4000, false, {})
        end
      end)
    end,
  }, function()
    job.process = nil
  end)
  if not ok then
    vim.notify('TeXpresso: failed to start: ' .. tostring(proc), vim.log.levels.ERROR)
    return
  end
  job.process = proc
  job.generation = {}
  M.theme()
  for buf, _ in pairs(job.attached) do
    if vim.api.nvim_buf_is_valid(buf) then
      M.reload(buf)
    else
      job.attached[buf] = nil
    end
  end
end

-- Hooks

vim.api.nvim_create_autocmd('ColorScheme', {
  callback = M.theme,
})

vim.api.nvim_create_autocmd('CursorMoved', {
  pattern = { '*.tex' },
  callback = M.synctex_forward_hook,
})

-- VIM commands

vim.api.nvim_create_user_command('TeXpresso', function(opts)
  M.launch(opts.fargs)
end, { nargs = '*', complete = 'file' })

return M

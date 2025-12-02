local ui = require("spelunk.ui")
local persist = require("spelunk.persistence")
local markmgr = require("spelunk.markmgr")
local util = require("spelunk.util")
local search = require("spelunk.fuzzy.search")

local M = {}

---@type PhysicalStack[]
local default_stacks = {
  { name = "Default", bookmarks = {} },
}
---@type integer
local current_stack_index = 1
---@type integer
local cursor_index = 1

---@type any
local window_config

---@type boolean
local enable_persist
---@type string
local statusline_prefix
---@type boolean
local show_status_col
---@type "snacks" | nil
local bookmark_finder_provider

---@param abspath string
---@return string
M.filename_formatter = function(abspath)
  return vim.fn.fnamemodify(abspath, ":~:.")
end

---@param mark Mark | PhysicalBookmark | FullBookmark
---@return string
M.display_function = function(mark)
  return string.format("%s:%d", M.filename_formatter(mark.file), mark.line)
end

---@return integer
M.get_current_stack_index = function()
  return current_stack_index
end

---@return UpdateWinOpts
local get_win_update_opts = function()
  ---@type string[]
  local lines = {}
  for _, mark in ipairs(markmgr.physical_stack(current_stack_index).bookmarks) do
    table.insert(lines, M.display_function(mark))
  end
  ---@type PhysicalBookmark | nil
  local mark
  if markmgr.valid_indices(current_stack_index, cursor_index) then
    mark = markmgr.physical_mark(current_stack_index, cursor_index)
  else
    mark = nil
  end
  return {
    cursor_index = cursor_index,
    title = markmgr.get_stack_name(current_stack_index),
    lines = lines,
    bookmark = mark,
    max_stack_size = markmgr.max_stack_len(),
  }
end

---@param updated_indices boolean
local update_window = function(updated_indices)
  if updated_indices and show_status_col then
    markmgr.update_indices(current_stack_index)
  end
  ui.update_window(get_win_update_opts())
  if show_status_col then
    util.set_extmarks_from_stack(markmgr.stacks()[current_stack_index])
  end
end

---@param file string
---@param line integer
---@param split "vertical" | "horizontal" | nil
local goto_position = function(file, line, col, split)
  if vim.fn.filereadable(file) ~= 1 then
    vim.notify("[spelunk.nvim] file being navigated to does not seem to exist: " .. file)
    return
  end
  if not split then
    vim.api.nvim_command("edit " .. file)
    vim.api.nvim_win_set_cursor(0, { line, col - 1 })
  elseif split == "vertical" then
    vim.api.nvim_command("vsplit " .. file)
    local new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(new_win, { line, col - 1 })
  elseif split == "horizontal" then
    vim.api.nvim_command("split " .. file)
    local new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(new_win, { line, col - 1 })
  else
    vim.notify("[spelunk.nvim] goto_position passed unsupported split: " .. split)
  end
end

M.toggle_window = function()
  ui.toggle_window(get_win_update_opts())
end

M.close_windows = function()
  ui.close_windows()
end

M.show_help = function()
  ui.show_help()
end

M.close_help = function()
  ui.close_help()
end

M.add_bookmark = function()
  if ui.is_open() then
    vim.notify("[spelunk.nvim] Cannot create bookmark while UI is open")
    return
  end
  markmgr.add_mark_current_pos(current_stack_index)
  update_window(true)
  M.persist()
end

--- Delete the bookmark from the current line, if there is one.
--- Bookmarks can also be deleted from the UI window, but that takes more keystrokes.
M.delete_bookmark = function()
  local file = vim.api.nvim_buf_get_name(0)
  local line = vim.fn.line(".")
  local mark_idx = markmgr.get_mark_idx_from_line(current_stack_index, file, line)
  if not mark_idx then
    vim.notify("[spelunk.nvim] No bookmark on line " .. line)
    return
  end

  markmgr.delete_mark(current_stack_index, mark_idx)
  update_window(true)
  M.persist()
  vim.notify(string.format("[spelunk.nvim] Deleted bookmark %d from line %d", mark_idx, line))
end

---@param direction 1 | -1
M.move_cursor = function(direction)
  if direction ~= 1 and direction ~= -1 then
    vim.notify("[spelunk.nvim] move_cursor passed invalid direction")
    return
  end
  cursor_index = markmgr.move_mark_idx(current_stack_index, cursor_index, direction)
  update_window(true)
end

---@param direction 1 | -1
M.move_bookmark = function(direction)
  if direction ~= 1 and direction ~= -1 then
    vim.notify("[spelunk.nvim] move_bookmark passed invalid direction")
    return
  end
  if not markmgr.move_mark_in_stack(current_stack_index, cursor_index, direction) then
    return
  end
  M.move_cursor(direction)
  M.persist()
end

---@param close boolean
---@param split "vertical" | "horizontal" | nil
local goto_bookmark = function(close, split)
  if cursor_index > 0 and cursor_index <= markmgr.len_marks(current_stack_index) then
    if close then
      M.close_windows()
    end
    vim.schedule(function()
      local mark = markmgr.physical_mark(current_stack_index, cursor_index)
      goto_position(mark.file, mark.line, mark.col, split)
    end)
  end
end

---@param idx integer
M.goto_bookmark_at_index = function(idx)
  if idx < 1 or idx > markmgr.len_marks(current_stack_index) then
    vim.notify("[spelunk.nvim] Given invalid index: " .. idx)
    return
  end
  cursor_index = idx
  goto_bookmark(true)
end

M.goto_selected_bookmark = function()
  goto_bookmark(true)
end

M.goto_selected_bookmark_horizontal_split = function()
  goto_bookmark(true, "horizontal")
end

M.goto_selected_bookmark_vertical_split = function()
  goto_bookmark(true, "vertical")
end

M.delete_selected_bookmark = function()
  cursor_index = markmgr.delete_mark(current_stack_index, cursor_index)
  update_window(true)
  M.persist()
end

---@param direction 1 | -1
M.select_and_goto_bookmark = function(direction)
  if ui.is_open() then
    return
  end
  if markmgr.len_marks(current_stack_index) == 0 then
    vim.notify("[spelunk.nvim] No bookmarks to go to")
    return
  end
  M.move_cursor(direction)
  goto_bookmark(false)
end

M.delete_current_stack = function()
  markmgr.delete_stack(current_stack_index)
  current_stack_index = 1
  update_window(false)
  M.persist()
end

M.edit_current_stack = function()
  local name =
    vim.fn.input("[spelunk.nvim] Enter new name for the stack: ", markmgr.get_stack_name(current_stack_index))
  if name == "" then
    return
  end
  markmgr.set_stack_name(current_stack_index, name)
  update_window(false)
  M.persist()
end

M.next_stack = function()
  current_stack_index = current_stack_index % markmgr.len_stacks() + 1
  cursor_index = 1
  update_window(false)
end

M.prev_stack = function()
  current_stack_index = (current_stack_index - 2) % markmgr.len_stacks() + 1
  cursor_index = 1
  update_window(false)
end

M.new_stack = function()
  local name = vim.fn.input("[spelunk.nvim] Enter name for new stack: ")
  if name and name ~= "" then
    local new_stack_idx = markmgr.add_stack(name)
    current_stack_index = new_stack_idx
    cursor_index = 1
    update_window(false)
  end
  M.persist()
end

M.persist = function()
  if enable_persist then
    persist.save(markmgr.physical_stacks())
  end
end

---@return FullBookmark[]
M.all_full_marks = function()
  local data = {}
  for _, stack in ipairs(markmgr.physical_stacks()) do
    for _, mark in ipairs(stack.bookmarks) do
      table.insert(data, {
        stack = stack.name,
        file = mark.file,
        line = mark.line,
        col = mark.col,
        meta = mark.meta,
      })
    end
  end
  return data
end

---@return FullBookmark[]
M.current_full_marks = function()
  local data = {}
  local stack = markmgr.physical_stack(current_stack_index)
  for _, mark in ipairs(stack.bookmarks) do
    table.insert(data, {
      stack = stack.name,
      file = mark.file,
      line = mark.line,
      col = mark.col,
      meta = mark.meta,
    })
  end
  return data
end

M.search_marks = function()
  search.search_marks({
    prompt = "[spelunk.nvim] All Marks",
    data = M.all_full_marks(),
    select_fn = goto_position,
    display_fn = M.display_function,
  })
end

M.search_current_marks = function()
  search.search_marks({
    prompt = "[spelunk.nvim] Current Stack Marks",
    data = M.current_full_marks(),
    select_fn = goto_position,
    display_fn = M.display_function,
  })
end

M.search_stacks = function(opts)
  Snacks.debug(opts)
  ---@param stack_name string
  local cb = function(stack_name)
    local stack_idx = markmgr.stack_idx_for_name(stack_name)
    if stack_idx < 0 then
      return
    end
    current_stack_index = stack_idx
    -- Use the fancy Snacks picker if configured, otherwise use the default UI window
    if opts.bookmark_finder_provider and opts.bookmark_finder_provider == "snacks" then
      M.toggle_snacks_picker()
    else
      M.toggle_window()
    end
  end
  search.search_stacks({
    prompt = "[spelunk.nvim] Stacks",
    data = markmgr.stacks(),
    select_fn = cb,
    display_fn = M.display_function,
  })
end

---@return string
M.statusline = function()
  local path = vim.fn.expand("%:p")
  return statusline_prefix .. " " .. markmgr.instances_of_file(path, current_stack_index)
end

---@param marks PhysicalBookmark[]
local open_marks_qf = function(marks)
  local qf_items = {}
  for _, mark in ipairs(marks) do
    table.insert(qf_items, {
      bufnr = vim.fn.bufnr(mark.file),
      lnum = mark.line,
      col = mark.col,
      text = vim.fn.getline(mark.line),
      type = "",
    })
  end
  vim.fn.setqflist(qf_items, "r")
  vim.cmd("copen")
end

M.qf_all_marks = function()
  ---@type PhysicalBookmark[]
  local marks = {}
  for _, stack in ipairs(markmgr.physical_stacks()) do
    for _, mark in ipairs(stack.bookmarks) do
      table.insert(marks, mark)
    end
  end
  open_marks_qf(marks)
end

M.qf_current_marks = function()
  ---@type PhysicalBookmark[]
  local marks = {}
  for _, mark in ipairs(markmgr.physical_stack(current_stack_index)) do
    table.insert(marks, mark)
  end
  open_marks_qf(marks)
end

---@param stack_idx integer
---@param mark_idx integer
---@param field string
---@param val any
M.add_mark_meta = function(stack_idx, mark_idx, field, val)
  markmgr.add_mark_meta(stack_idx, mark_idx, field, val)
  M.persist()
end

---@param stack_idx integer
---@param mark_idx integer
---@param field string
---@return any | nil
M.get_mark_meta = function(stack_idx, mark_idx, field)
  return markmgr.get_mark_meta(stack_idx, mark_idx, field)
end

---@param mark_index integer
local change_mark_line = function(mark_index)
  ---@type Mark
  local mark = markmgr.get_mark(current_stack_index, mark_index)
  local old_line = mark.line

  local new_line = tonumber(vim.fn.input("[spelunk.nvim] Move bookmark to line: "))
  if not new_line or new_line == 0 then
    return
  end

  if markmgr.line_has_mark(current_stack_index, mark.file, new_line) then
    vim.schedule(function()
      vim.notify("[spelunk.nvim] Line " .. new_line .. " already has a mark")
    end)
    return
  end

  if new_line == old_line then
    return
  end

  local nr_lines = util.line_count(mark.file)
  if new_line > nr_lines then
    vim.schedule(function()
      vim.notify("[spelunk.nvim] This file only has " .. nr_lines .. " lines", vim.log.levels.ERROR)
    end)
    return
  end

  mark.line = new_line

  M.persist()
  update_window(true)
  vim.schedule(function()
    vim.notify(string.format("[spelunk.nvim] Bookmark %d line change: %d -> %d", cursor_index, old_line, new_line))
  end)
end

--- Update the line of the mark on current file line, in the current stack.
M.change_line_of_mark_on_current_line = function()
  local line = vim.fn.line(".")
  ---@type integer | nil
  local mark_idx = markmgr.get_mark_idx_from_line(current_stack_index, vim.api.nvim_buf_get_name(0), line)
  if not mark_idx then
    vim.notify("[spelunk.nvim] No bookmark on line " .. line, vim.log.levels.ERROR)
    return
  end

  change_mark_line(mark_idx)
end

--- Update the line of the current mark.
M.change_line_of_current_mark = function()
  change_mark_line(cursor_index)
end

M.setup = function(c)
  local conf = c or {}
  local cfg = require("spelunk.config")
  local base_config = conf.base_mappings or {}
  cfg.apply_base_defaults(base_config)
  window_config = conf.window_mappings or {}
  cfg.apply_window_defaults(window_config)
  ui.setup(base_config, window_config, conf.cursor_character or cfg.get_default("cursor_character"))

  require("spelunk.layout").setup(conf.orientation or cfg.get_default("orientation"))

  show_status_col = conf.enable_status_col_display or cfg.get_default("enable_status_col_display")

  persist.setup(conf.persist_by_git_branch or cfg.get_default("persist_by_git_branch"))

  local fuzzy_search_provider = conf.fuzzy_search_provider or cfg.get_default("fuzzy_search_provider")
  search.setup(fuzzy_search_provider, ui.is_open)

  -- Load saved bookmarks, if enabled and available
  -- Otherwise, set defaults
  ---@type PhysicalStack[] | nil
  local physical_stacks
  enable_persist = conf.enable_persist or cfg.get_default("enable_persist")
  if enable_persist then
    physical_stacks = persist.load()
  end
  if not physical_stacks then
    physical_stacks = default_stacks
  end
  markmgr.init(physical_stacks, {
    persist_enabled = enable_persist,
    persist_cb = M.persist,
  }, show_status_col)

  -- Configure the prefix to use for the lualine integration
  statusline_prefix = conf.statusline_prefix or cfg.get_default("statusline_prefix")

  local set = cfg.set_keymap
  if conf.bookmark_finder_provider and conf.bookmark_finder_provider == "snacks" then
    set(base_config.toggle, M.toggle_snacks_picker, "[spelunk.nvim] Toggle Snacks Picker")
  else
    set(base_config.toggle, M.toggle_window, "[spelunk.nvim] Toggle UI")
  end
  set(base_config.add, M.add_bookmark, "[spelunk.nvim] Add bookmark")
  set(base_config.delete, M.delete_bookmark, "[spelunk.nvim] Delete current line bookmark")
  set(
    base_config.next_bookmark,
    ':lua require("spelunk").select_and_goto_bookmark(1)<CR>',
    "[spelunk.nvim] Go to next bookmark"
  )
  set(
    base_config.prev_bookmark,
    ':lua require("spelunk").select_and_goto_bookmark(-1)<CR>',
    "[spelunk.nvim] Go to previous bookmark"
  )
  set(base_config.change_line, M.change_line_of_mark_on_current_line, "[spelunk.nvim] Change bookmark line")

  set(base_config.search_bookmarks, M.search_marks, "[spelunk.nvim] Fuzzy find bookmarks")
  set(
    base_config.search_current_bookmarks,
    M.search_current_marks,
    "[spelunk.nvim] Fuzzy find bookmarks in current stack"
  )
  set(base_config.search_stacks, function()
    M.search_stacks(conf)
  end, "[spelunk.nvim] Fuzzy find stacks")
end

local snacks_full = require("spelunk.fuzzy.snacks_full")

-- Add this new function to replace toggle_window
M.toggle_snacks_picker = function()
  snacks_full.show_picker({
    -- Use a function to always get fresh stacks data
    get_stacks = function()
      return markmgr.physical_stacks()
    end,
    current_stack_index = current_stack_index,
    cursor_index = cursor_index,
    display_fn = M.display_function,

    -- Callbacks for picker actions
    callbacks = {
      goto_position = goto_position,
      goto_bookmark_at_index = M.goto_bookmark_at_index,

      move_bookmark = function(stack_idx, mark_idx, direction)
        if not markmgr.move_mark_in_stack(stack_idx, mark_idx, direction) then
          return false
        end
        M.persist()
        return true
      end,

      delete_mark = function(stack_idx, mark_idx)
        cursor_index = markmgr.delete_mark(stack_idx, mark_idx)
        M.persist()
        return cursor_index
      end,

      change_mark_line = function(stack_idx, mark_idx)
        local mark = markmgr.get_mark(stack_idx, mark_idx)
        local old_line = mark.line

        local new_line = tonumber(vim.fn.input("[spelunk.nvim] Move bookmark to line: "))
        if not new_line or new_line == 0 then
          return
        end

        if markmgr.line_has_mark(stack_idx, mark.file, new_line) then
          vim.schedule(function()
            vim.notify("[spelunk.nvim] Line " .. new_line .. " already has a mark")
          end)
          return
        end

        if new_line == old_line then
          return
        end

        local nr_lines = require("spelunk.util").line_count(mark.file)
        if new_line > nr_lines then
          vim.schedule(function()
            vim.notify("[spelunk.nvim] This file only has " .. nr_lines .. " lines", vim.log.levels.ERROR)
          end)
          return
        end

        mark.line = new_line
        M.persist()

        -- Update indices and status column extmarks
        if show_status_col then
          markmgr.update_indices(stack_idx)
          util.set_extmarks_from_stack(markmgr.stacks()[stack_idx])
        end

        vim.schedule(function()
          vim.notify(string.format("[spelunk.nvim] Bookmark %d line change: %d -> %d", mark_idx, old_line, new_line))
        end)
      end,

      new_stack = function()
        local name = vim.fn.input("[spelunk.nvim] Enter name for new stack: ")
        if name and name ~= "" then
          local new_stack_idx = markmgr.add_stack(name)
          M.persist()
          return new_stack_idx
        end
        return nil
      end,

      delete_stack = function(stack_idx)
        markmgr.delete_stack(stack_idx)
        M.persist()
      end,

      edit_stack = function(stack_idx)
        local name = vim.fn.input("[spelunk.nvim] Enter new name for the stack: ", markmgr.get_stack_name(stack_idx))
        if name == "" then
          return
        end
        markmgr.set_stack_name(stack_idx, name)
        M.persist()
      end,

      -- Edit bookmark alias (short label)
      edit_alias = function(stack_idx, mark_idx)
        local current_alias = markmgr.get_mark_meta(stack_idx, mark_idx, "alias") or ""

        local alias = vim.fn.input({
          prompt = "[spelunk.nvim] Alias (short label, max 20 chars): ",
          default = current_alias,
        })

        -- Cancel if user hits ESC or empty input
        if not alias then
          return
        end

        -- Update alias
        markmgr.add_mark_meta(stack_idx, mark_idx, "alias", alias)
        M.persist()

        vim.schedule(function()
          vim.notify(string.format("[spelunk.nvim] Updated alias for bookmark %d", mark_idx), vim.log.levels.INFO)
          M.toggle_snacks_picker()
        end)
      end,

      -- Edit bookmark note (multi-line)
      edit_note = function(stack_idx, mark_idx)
        local current_note = markmgr.get_mark_meta(stack_idx, mark_idx, "notes") or ""

        -- Create a temporary buffer for multi-line note editing
        local note_buf = vim.api.nvim_create_buf(false, true)
        local note_lines = vim.split(current_note, "\n", { plain = true })
        vim.api.nvim_buf_set_lines(note_buf, 0, -1, false, note_lines)

        -- Open in a floating window
        local width = math.min(80, vim.o.columns - 10)
        local height = math.min(20, vim.o.lines - 10)
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        local note_win = vim.api.nvim_open_win(note_buf, true, {
          relative = "editor",
          width = width,
          height = height,
          row = row,
          col = col,
          style = "minimal",
          border = "rounded",
          title = " Edit Note (<CR> to save, <Esc>/q to cancel) ",
          title_pos = "center",
        })

        vim.bo[note_buf].buftype = "nofile"
        vim.bo[note_buf].bufhidden = "wipe"
        vim.bo[note_buf].filetype = "markdown"

        -- Variable to track if saved
        local saved = false

        -- Save with <CR> in normal mode
        vim.keymap.set("n", "<CR>", function()
          local note = table.concat(vim.api.nvim_buf_get_lines(note_buf, 0, -1, false), "\n")
          saved = true

          -- Update note
          markmgr.add_mark_meta(stack_idx, mark_idx, "notes", note)
          M.persist()

          vim.api.nvim_win_close(note_win, true)

          vim.schedule(function()
            vim.notify(string.format("[spelunk.nvim] Updated note for bookmark %d", mark_idx), vim.log.levels.INFO)
            -- Reopen the picker
            M.toggle_snacks_picker()
          end)
        end, { buffer = note_buf, noremap = true, silent = true })

        -- Cancel with <Esc> in normal mode
        vim.keymap.set("n", "<Esc>", function()
          vim.api.nvim_win_close(note_win, true)
          vim.schedule(function()
            -- Reopen the picker
            M.toggle_snacks_picker()
          end)
        end, { buffer = note_buf, noremap = true, silent = true })
      end,

      -- Refresh callbacks to update extmarks
      refresh_indices = function(stack_idx)
        if show_status_col then
          markmgr.update_indices(stack_idx)
        end
      end,

      refresh_status_col = function(stack_idx)
        if show_status_col then
          util.set_extmarks_from_stack(markmgr.stacks()[stack_idx])
        end
      end,
    },

    -- Track stack/cursor changes
    on_stack_change = function(stack_idx)
      current_stack_index = stack_idx
      cursor_index = 1
    end,

    on_cursor_change = function(cursor_idx)
      cursor_index = cursor_idx
    end,
  })
end

return M

-- Full Snacks picker integration for Spelunk
-- This replaces the custom UI window with a Snacks picker

local status_ok, snacks = pcall(require, "snacks")
if not status_ok or not snacks then
  vim.notify("[spelunk.nvim] snacks.nvim is not installed, cannot be used", vim.log.levels.ERROR)
  return false
end

local M = {}

-- Meta display configuration
local META_CONFIG = {
  alias_max_length = 20, -- Display as virtual text if alias <= 20 chars
  alias_separator = " | ", -- Separator before alias
  alias_hl_group = "Comment", -- Highlight group for alias virtual text
  notes_indicator = " 📝", -- Icon to show when bookmark has notes
  notes_indicator_hl = "Special", -- Highlight group for notes indicator
  notes_border_char = "═", -- Character for notes header border
  notes_icon = "📝 Notes", -- Icon/label for notes header
  notes_border_hl = "WarningMsg", -- Highlight group for notes border
  notes_header_hl = "Title", -- Highlight group for notes header
  notes_content_hl = "Special", -- Highlight group for notes content
}

---@class SpelunkPickerOpts
---@field get_stacks fun(): PhysicalStack[]
---@field current_stack_index number
---@field cursor_index number
---@field display_fn fun(mark: Mark): string
---@field on_close? fun()
---@field on_stack_change? fun(stack_idx: number)
---@field on_cursor_change? fun(cursor_idx: number)
---@field callbacks table Callbacks for various actions

---@param opts SpelunkPickerOpts
M.show_picker = function(opts)
  local current_stack_idx = opts.current_stack_index or 1
  local current_cursor_idx = opts.cursor_index or 1
  local stacks = opts.get_stacks()
  local callbacks = opts.callbacks

  -- Build items from current stack
  local function build_items()
    local items = {}
    -- Always get the latest stacks reference
    stacks = opts.get_stacks()
    local current_stack = stacks[current_stack_idx]
    if not current_stack then
      return items
    end

    for idx, mark in ipairs(current_stack.bookmarks) do
      ---@type PhysicalBookmark
      local bookmark = mark
      ---@diagnostic disable-next-line: param-type-mismatch
      table.insert(items, {
        idx = idx,
        text = string.format("%2d %s", idx, opts.display_fn(bookmark)),
        file = bookmark.file,
        line = bookmark.line,
        col = bookmark.col,
        meta = bookmark.meta,
        stack_idx = current_stack_idx,
        mark_idx = idx,
        -- Add alias for virtual text rendering
        alias = bookmark.meta and bookmark.meta["alias"] or nil,
        -- Add notes flag for indicator
        has_notes = bookmark.meta and bookmark.meta.notes and bookmark.meta.notes ~= "",
      })
    end
    return items
  end

  local picker_instance = nil

  -- Refresh picker with new items
  local function refresh_picker()
    if picker_instance then
      -- Update stacks reference in case it was modified
      stacks = opts.get_stacks()
      local current_stack = stacks[current_stack_idx]
      if not current_stack then
        vim.notify("[spelunk.nvim] Invalid stack index: " .. current_stack_idx, vim.log.levels.ERROR)
        return
      end
      local new_items = build_items()
      local new_title = string.format("🔖 %s (%d/%d)", current_stack.name, current_stack_idx, #stacks)
      -- Alternative prompt style (commented out):
      -- local new_prompt = string.format("Stack %d/%d > ", current_stack_idx, #stacks)

      -- Update picker title
      picker_instance.opts.items = new_items
      picker_instance.opts.title = new_title
      picker_instance.title = new_title

      -- Update window title using the win object's title functionality
      if picker_instance.win then
        -- Try to update the title through the window object
        if picker_instance.win.set_title then
          picker_instance.win:set_title(new_title)
        end
        -- Also try updating through win opts
        if picker_instance.win.opts then
          picker_instance.win.opts.title = new_title
        end
      end

      -- Force a full refresh by recreating the finder
      picker_instance:find({ items = new_items, refresh = true })
    end
  end

  -- Custom actions
  local custom_actions = {
    -- Move cursor up/down
    cursor_down = function(picker)
      local items = picker:items()
      if #items == 0 then
        return
      end
      local current = picker.list:idx()
      local next_idx = math.min(current + 1, #items)
      picker.list:view(next_idx)
      current_cursor_idx = next_idx
      if opts.on_cursor_change then
        opts.on_cursor_change(current_cursor_idx)
      end
    end,

    cursor_up = function(picker)
      local items = picker:items()
      if #items == 0 then
        return
      end
      local current = picker.list:idx()
      local next_idx = math.max(current - 1, 1)
      picker.list:view(next_idx)
      current_cursor_idx = next_idx
      if opts.on_cursor_change then
        opts.on_cursor_change(current_cursor_idx)
      end
    end,

    -- Move bookmark up/down in stack
    bookmark_down = function(picker)
      local item = picker:current()
      if not item then
        return
      end
      if callbacks.move_bookmark then
        local success = callbacks.move_bookmark(current_stack_idx, item.mark_idx, 1)
        if success then
          -- Update stacks reference after move
          stacks = opts.get_stacks()
          local current_stack = stacks[current_stack_idx]
          if current_stack then
            current_cursor_idx = math.min(item.mark_idx + 1, #current_stack.bookmarks)
          end
          -- Refresh indices to update status column numbers
          if callbacks.refresh_indices then
            callbacks.refresh_indices(current_stack_idx)
          end
          refresh_picker()
          if picker.list and current_cursor_idx then
            vim.schedule(function()
              local items = picker:items()
              if items and #items > 0 and current_cursor_idx <= #items then
                picker.list:view(current_cursor_idx)
              end
            end)
          end
        end
      end
    end,

    bookmark_up = function(picker)
      local item = picker:current()
      if not item then
        return
      end
      if callbacks.move_bookmark then
        local success = callbacks.move_bookmark(current_stack_idx, item.mark_idx, -1)
        if success then
          -- Update stacks reference after move
          stacks = opts.get_stacks()
          local current_stack = stacks[current_stack_idx]
          if current_stack then
            current_cursor_idx = math.max(item.mark_idx - 1, 1)
          end
          -- Refresh indices to update status column numbers
          if callbacks.refresh_indices then
            callbacks.refresh_indices(current_stack_idx)
          end
          refresh_picker()
          if picker.list and current_cursor_idx then
            vim.schedule(function()
              local items = picker:items()
              if items and #items > 0 and current_cursor_idx <= #items then
                picker.list:view(current_cursor_idx)
              end
            end)
          end
        end
      end
    end,

    -- Go to bookmark
    goto_bookmark = function(picker)
      local item = picker:current()
      if not item then
        return
      end
      picker:close()
      if callbacks.goto_position then
        vim.schedule(function()
          callbacks.goto_position(item.file, item.line, item.col)
        end)
      end
    end,

    goto_bookmark_hsplit = function(picker)
      local item = picker:current()
      if not item then
        return
      end
      picker:close()
      if callbacks.goto_position then
        vim.schedule(function()
          callbacks.goto_position(item.file, item.line, item.col, "horizontal")
        end)
      end
    end,

    goto_bookmark_vsplit = function(picker)
      local item = picker:current()
      if not item then
        return
      end
      picker:close()
      if callbacks.goto_position then
        vim.schedule(function()
          callbacks.goto_position(item.file, item.line, item.col, "vertical")
        end)
      end
    end,

    -- Go to bookmark by number
    goto_bookmark_1 = function(p)
      p:close()
      if callbacks.goto_bookmark_at_index then
        callbacks.goto_bookmark_at_index(1)
      end
    end,
    goto_bookmark_2 = function(p)
      p:close()
      if callbacks.goto_bookmark_at_index then
        callbacks.goto_bookmark_at_index(2)
      end
    end,
    goto_bookmark_3 = function(p)
      p:close()
      if callbacks.goto_bookmark_at_index then
        callbacks.goto_bookmark_at_index(3)
      end
    end,
    goto_bookmark_4 = function(p)
      p:close()
      if callbacks.goto_bookmark_at_index then
        callbacks.goto_bookmark_at_index(4)
      end
    end,
    goto_bookmark_5 = function(p)
      p:close()
      if callbacks.goto_bookmark_at_index then
        callbacks.goto_bookmark_at_index(5)
      end
    end,
    goto_bookmark_6 = function(p)
      p:close()
      if callbacks.goto_bookmark_at_index then
        callbacks.goto_bookmark_at_index(6)
      end
    end,
    goto_bookmark_7 = function(p)
      p:close()
      if callbacks.goto_bookmark_at_index then
        callbacks.goto_bookmark_at_index(7)
      end
    end,
    goto_bookmark_8 = function(p)
      p:close()
      if callbacks.goto_bookmark_at_index then
        callbacks.goto_bookmark_at_index(8)
      end
    end,
    goto_bookmark_9 = function(p)
      p:close()
      if callbacks.goto_bookmark_at_index then
        callbacks.goto_bookmark_at_index(9)
      end
    end,

    -- Delete bookmark
    delete_bookmark = function(picker)
      local item = picker:current()
      if not item then
        return
      end
      if callbacks.delete_mark then
        current_cursor_idx = callbacks.delete_mark(current_stack_idx, item.mark_idx)
        refresh_picker()
        if picker.list and current_cursor_idx then
          vim.schedule(function()
            local items = picker:items()
            if items and #items > 0 and current_cursor_idx <= #items then
              picker.list:view(current_cursor_idx)
            end
          end)
        end
      end
    end,

    -- Change bookmark line
    change_line = function(picker)
      local item = picker:current()
      if not item then
        return
      end
      if callbacks.change_mark_line then
        callbacks.change_mark_line(current_stack_idx, item.mark_idx)
        refresh_picker()
      end
    end,

    -- Stack navigation
    next_stack = function(picker)
      -- Update stacks reference before navigation
      stacks = opts.get_stacks()
      current_stack_idx = current_stack_idx % #stacks + 1
      current_cursor_idx = 1
      if opts.on_stack_change then
        opts.on_stack_change(current_stack_idx)
      end
      -- Refresh status column for the new stack
      if callbacks.refresh_status_col then
        callbacks.refresh_status_col(current_stack_idx)
      end
      refresh_picker()
      if picker.list then
        vim.schedule(function()
          local items = picker:items()
          if items and #items > 0 then
            picker.list:view(1)
          end
        end)
      end
    end,

    previous_stack = function(picker)
      -- Update stacks reference before navigation
      stacks = opts.get_stacks()
      current_stack_idx = (current_stack_idx - 2) % #stacks + 1
      current_cursor_idx = 1
      if opts.on_stack_change then
        opts.on_stack_change(current_stack_idx)
      end
      -- Refresh status column for the new stack
      if callbacks.refresh_status_col then
        callbacks.refresh_status_col(current_stack_idx)
      end
      refresh_picker()
      if picker.list then
        vim.schedule(function()
          local items = picker:items()
          if items and #items > 0 then
            picker.list:view(1)
          end
        end)
      end
    end,

    -- Stack management
    new_stack = function(_)
      if callbacks.new_stack then
        local new_idx = callbacks.new_stack()
        if new_idx then
          -- Refresh stacks BEFORE accessing the new index
          stacks = opts.get_stacks()
          current_stack_idx = new_idx
          current_cursor_idx = 1
          if opts.on_stack_change then
            opts.on_stack_change(current_stack_idx)
          end
          -- Refresh status column for the new stack
          if callbacks.refresh_status_col then
            callbacks.refresh_status_col(current_stack_idx)
          end
          refresh_picker()
          -- Only try to view position if there are items
          if picker_instance and picker_instance.list then
            vim.schedule(function()
              local items = picker_instance:items()
              if items and #items > 0 then
                picker_instance.list:view(1)
              end
            end)
          end
        end
      end
    end,

    delete_stack = function(picker)
      if callbacks.delete_stack then
        callbacks.delete_stack(current_stack_idx)
        -- Update stacks reference after deletion
        stacks = opts.get_stacks()
        current_stack_idx = 1
        current_cursor_idx = 1
        if opts.on_stack_change then
          opts.on_stack_change(current_stack_idx)
        end
        -- Refresh status column for the new current stack
        if callbacks.refresh_status_col then
          callbacks.refresh_status_col(current_stack_idx)
        end
        refresh_picker()
        if picker and picker.list then
          vim.schedule(function()
            local items = picker:items()
            if items and #items > 0 then
              picker.list:view(1)
            end
          end)
        end
      end
    end,

    edit_stack = function(_)
      if callbacks.edit_stack then
        callbacks.edit_stack(current_stack_idx)
        refresh_picker()
      end
    end,

    -- Edit bookmark alias
    edit_alias = function(picker)
      local item = picker:current()
      if not item then
        return
      end

      if not callbacks.edit_alias then
        vim.notify("[spelunk.nvim] edit_alias callback not available", vim.log.levels.ERROR)
        return
      end

      -- Close picker temporarily to show edit input
      picker:close()

      -- Call edit_alias directly without extra scheduling
      callbacks.edit_alias(current_stack_idx, item.mark_idx)
    end,

    -- Edit bookmark notes
    edit_note = function(picker)
      local item = picker:current()
      if not item then
        return
      end

      if not callbacks.edit_note then
        vim.notify("[spelunk.nvim] edit_note callback not available", vim.log.levels.ERROR)
        return
      end

      -- Close picker temporarily to show edit window
      picker:close()

      -- Call edit_note directly without extra scheduling
      callbacks.edit_note(current_stack_idx, item.mark_idx)
    end,

    -- Help
    show_help = function(_)
      local help_text = [[
Spelunk Bookmarks Help
=====================

Navigation:
  j/k          - Cursor down/up
  <C-j>/<C-k>  - Move bookmark down/up in stack
  <CR>         - Go to bookmark
  x            - Go to bookmark in horizontal split
  v            - Go to bookmark in vertical split
  1-9          - Go to bookmark at index

Bookmark Management:
  d            - Delete bookmark
  l            - Change bookmark line
  ma           - Edit alias
  mn           - Edit notes

Stack Management:
  <Tab>        - Next stack
  <S-Tab>      - Previous stack
  n            - New stack
  D            - Delete current stack
  E            - Edit stack name

Other:
  q            - Close picker
  h            - Show this help
  ?            - Show picker help
]]
      vim.notify(help_text, vim.log.levels.INFO)
    end,
  }

  -- Custom format function to display alias and notes indicator as virtual text
  local format_item = function(item, picker)
    local ret = {}

    -- Main text
    ret[#ret + 1] = { item.text }

    local virt_text_parts = {}

    -- Add notes indicator if bookmark has notes
    if item.has_notes then
      table.insert(virt_text_parts, { META_CONFIG.notes_indicator, META_CONFIG.notes_indicator_hl })
    end

    -- Add alias as virtual text if it exists and is short enough
    if item.alias and item.alias ~= "" and #item.alias <= META_CONFIG.alias_max_length then
      if #virt_text_parts > 0 then
        -- Add separator before alias if notes indicator exists
        table.insert(virt_text_parts, { META_CONFIG.alias_separator, META_CONFIG.alias_hl_group })
      else
        -- Add separator before alias if it's the first item
        table.insert(virt_text_parts, { META_CONFIG.alias_separator, META_CONFIG.alias_hl_group })
      end
      table.insert(virt_text_parts, { item.alias, META_CONFIG.alias_hl_group })
    end

    -- Add virtual text if we have any
    if #virt_text_parts > 0 then
      ret[#ret + 1] = {
        col = 0,
        virt_text = virt_text_parts,
        virt_text_pos = "eol", -- End of line
        hl_mode = "combine",
      }
    end

    return ret
  end

  picker_instance = snacks.picker({
    title = string.format("🔖 %s (%d/%d)", stacks[current_stack_idx].name, current_stack_idx, #stacks),
    -- Alternative prompt style (commented out):
    -- prompt = string.format("Stack %d/%d > ", current_stack_idx, #stacks),
    items = build_items(),
    format = format_item,
    actions = custom_actions,
    focus = "list",
    preview = function(ctx)
      local item = ctx.item
      if not item or not item.file then
        return
      end

      local ok, lines = pcall(vim.fn.readfile, item.file)
      if not ok then
        ctx.preview:set_lines({ "[Error reading file: " .. item.file .. "]" })
        return
      end

      -- Set the file content
      ctx.preview:set_lines(lines)

      -- Set filetype for syntax highlighting
      local ft = vim.filetype.match({ filename = item.file })
      if ft then
        vim.bo[ctx.preview.win.buf].filetype = ft
      end

      -- Highlight the bookmarked line
      ctx.item.pos = { item.line, item.col }
      ctx.preview:loc()
    end,
    win = {
      input = {
        keys = {
          -- Override/extend default keys with Spelunk mappings
          ["j"] = { "cursor_down", mode = { "n" } },
          ["k"] = { "cursor_up", mode = { "n" } },
          ["<C-j>"] = { "bookmark_down", mode = { "n", "i" } },
          ["<C-k>"] = { "bookmark_up", mode = { "n", "i" } },
          ["<CR>"] = { "goto_bookmark", mode = { "n", "i" } },
          ["x"] = { "goto_bookmark_hsplit", mode = { "n" } },
          ["v"] = { "goto_bookmark_vsplit", mode = { "n" } },
          ["1"] = { "goto_bookmark_1", mode = { "n" } },
          ["2"] = { "goto_bookmark_2", mode = { "n" } },
          ["3"] = { "goto_bookmark_3", mode = { "n" } },
          ["4"] = { "goto_bookmark_4", mode = { "n" } },
          ["5"] = { "goto_bookmark_5", mode = { "n" } },
          ["6"] = { "goto_bookmark_6", mode = { "n" } },
          ["7"] = { "goto_bookmark_7", mode = { "n" } },
          ["8"] = { "goto_bookmark_8", mode = { "n" } },
          ["9"] = { "goto_bookmark_9", mode = { "n" } },
          ["d"] = { "delete_bookmark", mode = { "n" } },
          ["l"] = { "change_line", mode = { "n" } },
          ["ma"] = { "edit_alias", mode = { "n" } },
          ["mn"] = { "edit_note", mode = { "n" } },
          ["<Tab>"] = { "next_stack", mode = { "n", "i" } },
          ["<S-Tab>"] = { "previous_stack", mode = { "n", "i" } },
          ["n"] = { "new_stack", mode = { "n" } },
          ["D"] = { "delete_stack", mode = { "n" } },
          ["E"] = { "edit_stack", mode = { "n" } },
          ["h"] = { "show_help", mode = { "n" } },
          ["q"] = { "cancel", mode = { "n" } },
          ["<Esc>"] = { "cancel", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          -- List window mappings
          ["j"] = "list_down",
          ["k"] = "list_up",
          ["<C-j>"] = "bookmark_down",
          ["<C-k>"] = "bookmark_up",
          ["<CR>"] = "goto_bookmark",
          ["x"] = "goto_bookmark_hsplit",
          ["v"] = "goto_bookmark_vsplit",
          ["1"] = "goto_bookmark_1",
          ["2"] = "goto_bookmark_2",
          ["3"] = "goto_bookmark_3",
          ["4"] = "goto_bookmark_4",
          ["5"] = "goto_bookmark_5",
          ["6"] = "goto_bookmark_6",
          ["7"] = "goto_bookmark_7",
          ["8"] = "goto_bookmark_8",
          ["9"] = "goto_bookmark_9",
          ["d"] = "delete_bookmark",
          ["l"] = "change_line",
          ["ma"] = "edit_alias",
          ["mn"] = "edit_note",
          ["<Tab>"] = "next_stack",
          ["<S-Tab>"] = "previous_stack",
          ["n"] = "new_stack",
          ["D"] = "delete_stack",
          ["E"] = "edit_stack",
          ["h"] = "show_help",
          ["q"] = "cancel",
          ["<Esc>"] = "cancel",
        },
      },
    },
    on_close = function()
      if opts.on_close then
        opts.on_close()
      end
    end,
    -- Set initial cursor position
    on_show = function(picker)
      if current_cursor_idx > 0 and current_cursor_idx <= #picker:items() then
        picker.list:view(current_cursor_idx)
      end
    end,
  })

  picker_instance:find()
  return picker_instance
end

return M

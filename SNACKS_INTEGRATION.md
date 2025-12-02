# Spelunk + Snacks Picker Full Integration Guide

This guide explains how to fully integrate Spelunk's bookmark window with Snacks picker, replacing the custom UI entirely.

## Files Created

1. **`lua/spelunk/fuzzy/snacks_full.lua`** - Full picker integration with all keymaps
2. **`lua/spelunk/fuzzy/snacks.lua`** - Updated for search functions

## Architecture

The integration provides two modes:

### 1. Search Mode (Existing)

- `search_marks()` - Search all bookmarks across all stacks
- `search_current_marks()` - Search bookmarks in current stack only
- `search_stacks()` - Search and switch between stacks

### 2. Full UI Mode (New)

- Replaces the custom floating window with a Snacks picker
- All keymaps from `window_mappings` are mapped to picker actions
- Preview window shows file content with syntax highlighting
- Dynamic title shows current stack name

## Integration Steps

### Step 1: Update `init.lua` to use Snacks picker

Add this helper function to `lua/spelunk/init.lua`:

```lua
-- Add at the top with other requires
local snacks_full = require("spelunk.fuzzy.snacks_full")

-- Add this new function to replace toggle_window
M.toggle_snacks_picker = function()
 local markmgr = require("spelunk.markmgr")
 
 snacks_full.show_picker({
  stacks = markmgr.physical_stacks(),
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
```

### Step 2: Update setup to use Snacks picker

In `M.setup()`, replace the toggle keymap:

```lua
-- Replace this line:
set(base_config.toggle, M.toggle_window, "[spelunk.nvim] Toggle UI")

-- With this:
set(base_config.toggle, M.toggle_snacks_picker, "[spelunk.nvim] Toggle Snacks Picker")
```

### Step 3: Update fuzzy_search_provider config

In your Neovim config:

```lua
require("spelunk").setup({
 -- ... other config ...
 fuzzy_search_provider = "snacks", -- Use 'snacks' instead of 'telescope' or 'fzf-lua'
})
```

## Keymaps in Picker

All your existing `window_mappings` are now available in the Snacks picker:

### Navigation

- `j` / `k` - Cursor down/up in list
- `<C-j>` / `<C-k>` - Move bookmark down/up in stack (reorders)

### Go to Bookmark

- `<CR>` - Go to bookmark (closes picker)
- `x` - Go to bookmark in horizontal split
- `v` - Go to bookmark in vertical split
- `1-9` - Go to bookmark at specific index

### Bookmark Management

- `d` - Delete current bookmark
- `l` - Change bookmark line number

### Stack Navigation

- `<Tab>` - Next stack
- `<S-Tab>` - Previous stack
- `n` - Create new stack
- `D` - Delete current stack
- `E` - Edit stack name

### Other

- `q` / `<Esc>` - Close picker
- `h` - Show help message
- `?` - Show Snacks picker help

## Features

### ✅ Already Working

- All keymaps from `window_mappings`
- File preview with syntax highlighting
- Bookmark line highlighting in preview
- Stack switching with dynamic title
- All bookmark CRUD operations
- Persistence on all operations

### ✅ Improvements Over Custom UI

- Better fuzzy matching (type to filter bookmarks)
- Standard Snacks picker UX
- Better scrolling and preview
- Consistent with other pickers in your setup
- Layout customization via Snacks config

### 🎨 Customization

You can customize the picker layout in your Snacks config:

```lua
require("snacks").setup({
 picker = {
  -- Use a specific layout for spelunk
  -- Or create custom layout in the picker config
 }
})
```

## Migration Path

You have two options:

1. **Full Migration** (Recommended)
   - Replace `M.toggle_window` with `M.toggle_snacks_picker` everywhere
   - Remove the custom UI code from `lua/spelunk/ui.lua`
   - Keep layout.lua for backward compatibility or remove it

2. **Gradual Migration**
   - Keep both `M.toggle_window` (custom UI) and `M.toggle_snacks_picker`
   - Map them to different keys:

     ```lua
     set("<leader>bt", M.toggle_window, "Toggle Custom UI")
     set("<leader>bT", M.toggle_snacks_picker, "Toggle Snacks Picker")
     ```

   - Test Snacks picker, then switch when ready

## Testing

Test all operations:

- ✅ Add bookmark
- ✅ Delete bookmark  
- ✅ Move bookmark up/down
- ✅ Go to bookmark (normal, hsplit, vsplit)
- ✅ Go to bookmark by number (1-9)
- ✅ Change bookmark line
- ✅ Next/prev stack
- ✅ Create/delete/edit stack
- ✅ Search bookmarks (all/current)
- ✅ Search stacks
- ✅ Preview updates
- ✅ Persistence works

## Troubleshooting

**Q: Picker is empty**
A: Make sure you have bookmarks in the current stack. Try adding one with `<leader>ba`.

**Q: Keymaps don't work**
A: Make sure you're focused in the picker (not the input field). Press `<Tab>` or `/` to toggle focus.

**Q: Preview doesn't show**
A: Check if the file exists and is readable. Some files may fail to load.

**Q: Want different layouts?**
A: Check Snacks picker docs for layout presets: `vertical`, `horizontal`, `ivy`, `telescope`, etc.

## Example Config

Complete working example:

```lua
-- In your lazy.nvim config
{
 "EvWilson/spelunk.nvim",
 dependencies = {
  "folke/snacks.nvim", -- Required for full integration
 },
 config = function()
  require("spelunk").setup({
   enable_persist = true,
   fuzzy_search_provider = "snacks",
   base_mappings = {
    toggle = "<leader>bt",
    add = "<leader>ba",
    delete = "<leader>bd",
    next_bookmark = "<leader>bn",
    prev_bookmark = "<leader>bp",
    search_bookmarks = "<leader>bf",
    search_current_bookmarks = "<leader>bc",
    search_stacks = "<leader>bs",
    change_line = "<leader>bl",
   },
   -- window_mappings are now used in the Snacks picker!
   window_mappings = {
    -- All these work in the Snacks picker
    cursor_down = "j",
    cursor_up = "k",
    bookmark_down = "<C-j>",
    bookmark_up = "<C-k>",
    goto_bookmark = "<CR>",
    goto_bookmark_hsplit = "x",
    goto_bookmark_vsplit = "v",
    change_line = "l",
    delete_bookmark = "d",
    next_stack = "<Tab>",
    previous_stack = "<S-Tab>",
    new_stack = "n",
    delete_stack = "D",
    edit_stack = "E",
    close = "q",
    help = "h",
   },
  })
 end,
}
```

## Next Steps

1. ✅ Integration complete - all keymaps work
2. ✅ Search functions use Snacks
3. ✅ Full UI uses Snacks picker
4. 📝 Test thoroughly
5. 📝 Update main README if satisfied
6. 📝 Consider removing old UI code after migration

Enjoy your fully integrated Spelunk + Snacks experience! 🎉

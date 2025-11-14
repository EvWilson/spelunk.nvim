# spelunk.nvim

Marks not cutting it? Create and manage bookmarks more easily, with an easy to use and configurable UI.

![Demo](assets/demo.gif)

## Design Goals
Programming often involves navigating between similar points of interest. Additionally, layers of functionality are often composed together, and thus are often read and edited as part of a stack. `spelunk.nvim` leans into this mental model to allow you to manage bookmarks as related stacks.

`spelunk.nvim` also seeks to take an opinionated approach to configuration. Default keymaps are provided to give the full experience out of the box, as opposed to a build-your-own, API-centric approach. API documentation is provided for those who would prefer to customize their experience.

## Features
- Capture and manage bookmarks as stacks of line number locations
- Opt-in persistence of bookmarks on a per-directory basis
- Togglable UI, with contextual and rebindable controls
	- Can also customize layout and panel rendering
- Cycle bookmarks via keybind
- Jump directly to bookmark by index
- Telescope integration - fuzzy find over bookmarks and stacks
- Lualine integration - show the number of bookmarks in the current buffer
- Sign column index display
- Mark aliases
- Treesitter integration - optionally show grammar context
- Opt-in git branch persistence scoping

See the `faqs/` directory for more custom setup guides.

## Requirements
Neovim (**stable** only) >= 0.11.0

## Installation/Configuration
Via [lazy](https://github.com/folke/lazy.nvim):
```lua
require('lazy').setup({
	{
		'EvWilson/spelunk.nvim',
		dependencies = {
			'nvim-telescope/telescope.nvim',   -- Optional: for fuzzy search capabilities
			'nvim-treesitter/nvim-treesitter', -- Optional: for showing grammar context
		},
		config = function()
			require('spelunk').setup({
				enable_persist = true
			})
		end
	}
})
```

Want to configure more keybinds? Pass a config object to the setup function.
Here's the default mapping object for reference:
```lua
{
	base_mappings = {
		-- Toggle the UI open/closed
		toggle = '<leader>bt',
		-- Add a bookmark to the current stack
		add = '<leader>ba',
		-- Move to the next bookmark in the stack
		next_bookmark = '<leader>bn',
		-- Move to the previous bookmark in the stack
		prev_bookmark = '<leader>bp',
		-- Fuzzy-find all bookmarks
		search_bookmarks = '<leader>bf',
		-- Fuzzy-find bookmarks in current stack
		search_current_bookmarks = '<leader>bc',
		-- Fuzzy find all stacks
		search_stacks = '<leader>bs',
	},
	window_mappings = {
		-- Move the UI cursor down
		cursor_down = 'j',
		-- Move the UI cursor up
		cursor_up = 'k',
		-- Move the current bookmark down in the stack
		bookmark_down = '<C-j>',
		-- Move the current bookmark up in the stack
		bookmark_up = '<C-k>',
		-- Jump to the selected bookmark
		goto_bookmark = '<CR>',
		-- Jump to the selected bookmark in a new vertical split
		goto_bookmark_hsplit = 'x',
		-- Jump to the selected bookmark in a new horizontal split
		goto_bookmark_vsplit = 'v',
		-- Delete the selected bookmark
		delete_bookmark = 'd',
		-- Navigate to the next stack
		next_stack = '<Tab>',
		-- Navigate to the previous stack
		previous_stack = '<S-Tab>',
		-- Create a new stack
		new_stack = 'n',
		-- Delete the current stack
		delete_stack = 'D',
		-- Rename the current stack
		edit_stack = 'E',
		-- Close the UI
		close = 'q',
		-- Open the help menu
		help = 'h',
	},
	-- Flag to enable directory-scoped bookmark persistence
	enable_persist = false,
	-- Prefix for the Lualine integration
	-- (Change this if your terminal emulator lacks emoji support)
	statusline_prefix = '🔖',
	-- Set UI orientation
	-- Type: 'vertical' | 'horizontal' | LayoutProvider
	-- Advanced customization: you may set your own layout provider for fine-grained control over layout
	-- See `layout.lua` for guidance on setting this up
	orientation = 'vertical',
	-- Enable to show mark index in status column
	enable_status_col_display = false,
	-- The character rendered before the currently selected bookmark in the UI
	cursor_character = '>',
	-- Set whether or not to persist bookmarks per git branch
	persist_by_git_branch = false,
}
```

Want to not set a keybind for a given action? Set the bound value to `'NONE'` and it will skip being set.
Keybinds can be set to either individual strings or arrays of strings, so for example `window_mappings.cursor_down` above could be mapped to `{ 'j', '<leader>s' }`.

Check the mentioned help screen to see current keybinds and their use:

![Help](assets/help.png)

### Lualine integration
A default integration with [lualine](https://github.com/nvim-lualine/lualine.nvim) is provided to show the number of active bookmarks in the current buffer. You may override the prefix for this string in the config map above. The result of the provided configuration here can be seen in the demo video above, in the bottom left of the screen.
```lua
  {
    'nvim-lualine/lualine.nvim',
    config = function()
      require('lualine').setup {
        sections = {
          lualine_b = { 'spelunk' },
	  -- Or, added to the default lualine_b config from here: https://github.com/nvim-lualine/lualine.nvim?tab=readme-ov-file#default-configuration
          -- lualine_b = { 'branch', 'diff', 'diagnostics', 'spelunk' },
        },
      }
    end
  },

```

## API Documentation
Here be dragons! This plugin is designed with the default bindings in mind, so there is potential for misuse here. This list will be non-exhaustive to cover just the most useful available functions, with the least potential for sharp edges.

All functions listed can be called like such from within Neovim Lua code:
```lua
require('spelunk').setup(opts)
```

If there is functionality you'd like to see added or exposed, please feel free to open an issue!

- `filename_formatter`
	- Description: function determining how to format bookmark file names for display
	- Type: `fun(abspath: string): string`
	- Default value:
	```lua
	function(abspath)
		return vim.fn.fnamemodify(abspath, ':~:.')
	end
	```

- `display_function`
	- Description: function determining how to format the full displayed string
	- Type: `fun(mark: PhysicalBookmark | FullBookmark): string`
	- Default value:
	```lua
	M.display_function = function(mark)
		return string.format('%s:%d', M.filename_formatter(mark.file), mark.line)
	end
	```

- `setup(config)`
	- Description: initialize the plugin, should be called to opt-in to default behavior
	- Parameters:
		- `config: table`: a table in the format given in the above Configuration section

- `toggle_window()`
	- Description: toggle the UI open/closed

- `close_windows()`
	- Description: close the UI, if open

- `add_bookmark()`
	- Description: add the line under the cursor as a bookmark

- `move_cursor(direction)`
	- Description: move the cursor in the UI (and underlying state) in the provided direction
	- Parameters:
		- `direction: integer` (1 | -1): direction to move the cursor, 1 is down, -1 is up

- `move_bookmark(direction)`
	- Description: move the bookmark in the UI (and underlying state) in the provided direction
	- Parameters:
		- `direction: integer` (1 | -1): direction to move the bookmark, 1 is down, -1 is up

- `goto_selected_bookmark()`
	- Description: navigate to the bookmark currently under the cursor in the UI

- `goto_selected_bookmark_horizontal_split()`
	- Description: navigate to the bookmark currently under the cursor in the UI, in a new horizontal split

- `goto_selected_bookmark_vertical_split()`
	- Description: navigate to the bookmark currently under the cursor in the UI, in a new vertical split

- `goto_bookmark_at_index(idx)`
	- Description: navigate to the bookmark at the given index in the current stack
	- Parameters:
		- `idx: integer`: index of the bookmark to navigate to

- `delete_selected_bookmark()`
	- Description: delete the bookmark currently under the cursor in the UI

- `select_and_goto_bookmark(direction)`
	- Description: move the cursor in the given direction, then go to that bookmark
	- Parameters:
		- `direction: integer` (1 | -1): direction to move the cursor, 1 is down, -1 is up

- `delete_current_stack()`
	- Description: delete the currently selected stack

- `edit_current_stack()`
	- Description: edit the name of the currently selected stack

- `next_stack()`
	- Description: move to the next stack

- `prev_stack()`
	- Description: move to the previous stack

- `new_stack()`
	- Description: create a new stack

- `search_marks()`
	- Description: fuzzy find over all bookmkarks using the Telescope integration

- `search_current_marks()`
	- Description: fuzzy find over bookmkarks in the current stack using the Telescope integration

- `statusline()`
	- Description: get the value that would be set in the status line for the Lualine integration
	- Returns:
		- `string`

- `all_full_marks()`
	- Description: return all marks
	- Returns:
		- `FullBookmark[]`

- `current_full_marks()`
	- Description: return all marks in the current stack
	- Returns:
		- `FullBookmark[]`

- `qf_all_marks()`
	- Description: open all mark locations in the quickfix list

- `qf_current_marks()`
	- Description: open current stack's mark locations in the quickfix list

- `add_mark_meta`
	- Description: add a value to a string key in the current mark's metadata table, can be used to create aliases or otherwise (see `faqs/`)
	- Parameters:
		- `stack_idx: integer`: index of the intended stack
		- `mark_idx: integer`: index of the intended mark
		- `field: string`: field in the metadata object to assign to
		- `val: any`: value to assign to the field

- `get_mark_meta`
	- Description: retrieve a value from a mark's metadata table
	- Parameters:
		- `stack_idx: integer`: index of the intended stack
		- `mark_idx: integer`: index of the intended mark
		- `field: string`: field in the metadata object to pull the value of
	- Returns:
		- `any | nil`

- `require('spelunk.util').get_treesitter_context(mark)`
	- Description: specially-scoped function to get the context of the given mark, in terms of chained Treesitter contexts
	- Disclaimer: this function is best-effort and incubatory, please open an issue if it's misbehaving and see the guide in `faqs/` for usage
	- Parameters:
		- `mark: PhysicalBookmark`
	- Returns:
		- `string`

### API Questions?
Some examples are available in th [`faqs`](faqs/) directory. If there's something you'd like to know how to do, please open an issue and we can see about implementing it!

Currently there are guides on:
- Providing a custom formatter for display filenames
- Overriding the display function altogether to show Treesitter context instead of mark location
- Not rendering the preview UI pane, which applies to all UI panes
- Setting custom aliases for marks

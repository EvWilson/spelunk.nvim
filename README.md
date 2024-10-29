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
- Cycle bookmarks via keybind
- Telescope integration - fuzzy find over all bookmarks, or those in the current stack
- Lualine integration - show the number of bookmarks in the current buffer

## Requirements
Neovim (**stable** only) >= 0.10.0

## Installation/Configuration
Via [lazy](https://github.com/folke/lazy.nvim):
```lua
require('lazy').setup({
	{
		'EvWilson/spelunk.nvim',
		dependencies = {
			'nvim-lua/plenary.nvim',         -- For window drawing utilities
			'nvim-telescope/telescope.nvim', -- Optional: for fuzzy search capabilities
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
		toggle = '<leader>bt',
		add = '<leader>ba',
		next_bookmark = '<leader>bn',
		prev_bookmark = '<leader>bp',
		search_bookmarks = '<leader>bf',
		search_current_bookmarks = '<leader>bc'
	},
	window_mappings = {
		cursor_down = 'j',
		cursor_up = 'k',
		bookmark_down = '<C-j>',
		bookmark_up = '<C-k',
		goto_bookmark = '<CR>',
		delete_bookmark = 'd',
		next_stack = '<Tab>',
		previous_stack = '<S-Tab>',
		new_stack = 'n',
		delete_stack = 'D',
		edit_stack = 'E',
		close = 'q',
		help = 'h', -- Not rebindable
	},
	enable_persist = false,
	statusline_prefix = '🔖',
}
```

Check the mentioned help screen to see current keybinds and their use:

![Help](assets/help.png)

### Lualine integration
A default integration with [lualine](https://github.com/nvim-lualine/lualine.nvim) is provided to show the number of active bookmarks in the current buffer. You may override the prefix for this string in the config map above.
```lua
  {
    'nvim-lualine/lualine.nvim',
    config = function()
      require('lualine').setup {
        sections = {
          lualine_b = {
            'spelunk'
          },
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

- `setup(config)`
	- Description: initialize the plugin, should be called to opt-in to default behavior
	- Parameters:
		- `config` - `table`: a table in the format given in the above Configuration section

- `toggle_window()`
	- Description: toggle the UI open/closed

- `close_windows()`
	- Description: close the UI, if open

- `add_bookmark()`
	- Description: add the line under the cursor as a bookmark

- `move_cursor(direction)`
	- Description: move the cursor in the UI (and underlying state) in the provided direction
	- Parameters:
		- `direction` - `integer` (1 | -1): direction to move the cursor, 1 is down, -1 is up

- `move_bookmark(direction)`
	- Description: move the bookmark in the UI (and underlying state) in the provided direction
	- Parameters:
		- `direction` - `integer` (1 | -1): direction to move the bookmark, 1 is down, -1 is up

- `goto_selected_bookmark()`
	- Description: navigate to the bookmark currently under the cursor in the UI

- `delete_selected_bookmark()`
	- Description: delete the bookmark currently under the cursor in the UI

- `select_and_goto_bookmark(direction)`
	- Description: move the cursor in the given direction, then go to that bookmark
	- Parameters:
		- `direction` - `integer` (1 | -1): direction to move the cursor, 1 is down, -1 is up

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


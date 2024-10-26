# spelunk.nvim

Marks not cutting it? Create and manage bookmarks more easily, with an easy to use and configurable UI.

![Demo](assets/demo.gif)

## Design Goals
Programming often involves navigating between similar points of interest. Additionally, layers of functionality are often composed together, and thus are often read and edited as part of a stack. `spelunk.nvim` leans into this mental model to allow you to manage bookmarks as related stacks.

## Features
- Capture and manage bookmarks as stacks of line number locations
- Opt-in persistence of bookmarks on a per-directory basis
- Togglable UI, with contextual and rebindable controls

## Requirements
Neovim (**stable** only) >= 0.10.0

## Installation/Configuration
Via [lazy](https://github.com/folke/lazy.nvim):
```lua
require("lazy").setup({
	{
		'EvWilson/spelunk.nvim',
		dependencies = { 'nvim-lua/plenary.nvim' },
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
		close = 'q',
		help = 'h', -- Not rebindable
	},
	enable_persist = false,
}
```

Check the mentioned help screen to see current keybinds and their use:

![Help](assets/help.png)

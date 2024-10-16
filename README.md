# spelunk.nvim

Marks not cutting it? Create and manage bookmarks more easily, with an easy to use and configurable UI.

![Demo](assets/demo.gif)

## Installation/Configuration
Via [lazy](https://github.com/folke/lazy.nvim):
```lua
require("lazy").setup({
	{
		'EvWilson/spelunk.nvim',
		dependencies = { 'nvim-lua/plenary.nvim' },
		config = function()
			require('spelunk').setup()
		end
	}
})
```

Want to configure the keybinds? Pass a config object to the setup function.
Here's the default mapping object for reference:
```lua
{
	base_mappings = {
		toggle = '<leader>bt',
		add = '<leader>ba'
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
	}
}
```

## Compatibility/Support

This project will attempt to support the latest Neovim stable release. Issues or incompatibilities only replicable
in nightly releases, or sufficiently older versions (>2 major versions back) will not be supported.

Thank you for your understanding!

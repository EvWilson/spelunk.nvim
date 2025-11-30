# Lualine Integration

A default integration with [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) is provided to show the number of active bookmarks in the current buffer. You may override the prefix for this string in the config map above. The result of the provided configuration here can be seen in the demo video above, in the bottom left of the screen.

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

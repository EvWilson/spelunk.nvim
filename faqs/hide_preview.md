# Hide the Preview UI Pane

Some folks would prefer to hide the preview UI pane and just have the main bookmark stack rendered. This is possible by leaving off the dimension function for the pane you'd prefer not to render when supplying your own custom `LayoutProvider`.

Here's an example of leaving the preview UI pane un-rendered, with a sample `lazy.nvim` spec:
```lua
{
	'EvWilson/spelunk.nvim',
	dependencies = {
		'nvim-lua/plenary.nvim',
	},
	config = function()
	local spelunk = require('spelunk')
	spelunk.setup({
		orientation = {
			bookmark_dimensions = function()
				return {
					base = base_dimensions(),
					line = 0,
					col = 0,
				}
			end,
			help_dimensions = function()
				return {
					base = base_dimensions(),
					line = 0,
					col = 0,
				}
			end,
		},
	})
	end
},
```

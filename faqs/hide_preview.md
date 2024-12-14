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
	local function width_portion()
		return math.floor(vim.o.columns / 20)
	end
	local function height_portion()
		return math.floor(vim.o.lines / 12)
	end
	local base_dimensions = function()
		return {
			width = width_portion() * 16,
			height = height_portion() * 5,
		}
	end
	spelunk.setup({
		orientation = {
			bookmark_dimensions = function()
				local dims = base_dimensions()
				return {
					base = dims,
					line = height_portion() * 5,
					col = width_portion() * 2,
				}
			end,
			help_dimensions = function()
				local dims = base_dimensions()
				return {
					base = dims,
					line = height_portion() * 3,
					col = width_portion() * 2,
				}
			end,
		},
	})
	end
},
```

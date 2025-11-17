# Display Treesitter Context in UI

As mentioned in the README API section, a display function is exposed to allow you to alter the display of stored marks to your liking.

The default display function is as follows:
```lua
local spelunk = require('spelunk')
---@param mark PhysicalBookmark | FullBookmark
---@return string
spelunk.display_function = function(mark)
	return string.format('%s:%d', spelunk.filename_formatter(mark.file), mark.line)
end
```

If you'd like to change this to display the Treesitter context for the current mark, here's a minimal example config block to achieve that end:
```lua
{
	'EvWilson/spelunk.nvim',
	config = function()
		local spelunk = require('spelunk')
		spelunk.setup()
		spelunk.display_function = function(mark)
			local ctx = require('spelunk.util').get_treesitter_context(mark)
			ctx = (ctx == '' and ctx) or (' - ' .. ctx)
			local filename = spelunk.filename_formatter(mark.file)
			return string.format("%s:%d%s", filename, mark.line, ctx)
		end
	end
}
```

Feel free to adjust this to suit your needs, for example by fusing it with the default shown above! An example:
```lua
spelunk.display_function = function(mark)
	return string.format('%s:%d - %s', spelunk.filename_formatter(mark.file), mark.line,
		require('spelunk.util').get_treesitter_context(mark))
end
```

Note: due to the fact that spelunk does not proactively load buffers, Treesitter context information will only be available once
a file has been loaded into a buffer for the first time.

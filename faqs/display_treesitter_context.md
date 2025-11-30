# Display Treesitter Context in UI

As mentioned in the README API section, a display function is exposed to allow you to alter the display of stored bookmarks to your liking.

The default display function is as follows:
```lua
local spelunk = require('spelunk')
---@param bookmark PhysicalBookmark | FullBookmark
---@return string
spelunk.display_function = function(bookmark)
	return string.format('%s:%d', spelunk.filename_formatter(bookmark.file), bookmark.line)
end
```

If you'd like to change this to display the Treesitter context for the current bookmark, here's a minimal example config block to achieve that end:
```lua
{
	'EvWilson/spelunk.nvim',
	config = function()
		local spelunk = require('spelunk')
		spelunk.setup()
		spelunk.display_function = function(bookmark)
			local ctx = require('spelunk.util').get_treesitter_context(bookmark)
			ctx = (ctx == '' and ctx) or (' - ' .. ctx)
			local filename = spelunk.filename_formatter(bookmark.file)
			return string.format("%s:%d%s", filename, bookmark.line, ctx)
		end
	end
}
```

Feel free to adjust this to suit your needs, for example by fusing it with the default shown above! An example:
```lua
spelunk.display_function = function(bookmark)
	return string.format('%s:%d - %s', spelunk.filename_formatter(bookmark.file), bookmark.line,
		require('spelunk.util').get_treesitter_context(bookmark))
end
```

Note: due to the fact that spelunk does not proactively load buffers, Treesitter context information will only be available once
a file has been loaded into a buffer for the first time.

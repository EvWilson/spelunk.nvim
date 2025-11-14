# Add and Show Mark Metadata

Some folks want to add custom aliases for bookmarks. This is a sample setup for achieving that purpose. It creates a keybind to set a field on the metadata object for the current mark, and then overriding the display function to optionally pull the display string from that tag, otherwise falling back to the default behavior.

```lua
{
	'EvWilson/spelunk.nvim',
	dependencies = {
		'nvim-telescope/telescope.nvim',
	},
	config = function()
		local spelunk = require('spelunk')
		spelunk.setup({
			enable_persist = true,
		})
		spelunk.display_function = function(mark)
			local alias = mark.meta['alias']
			if alias then
				return alias
			end
			local filename = spelunk.filename_formatter(mark.file)
			return string.format("%s:%d", filename, mark.line)
		end
		set('n', '<leader>bm', function()
			local alias = vim.fn.input({
				prompt = '[spelunk.nvim] Alias to attach to current mark: '
			})
			spelunk.add_mark_meta('alias', alias)
		end)
	end
},
```

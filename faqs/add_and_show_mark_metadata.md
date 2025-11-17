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

Similar to the above, but:
- add a name to the bookmark on the hovered line (if it exists)
- still include the filename and line number when displaying the bookmarks, even if you've named them

```lua
{
	'EvWilson/spelunk.nvim',
	dependencies = {
		'nvim-telescope/telescope.nvim',
	},
    opts = { enable_persist = true, enable_status_col_display = true },
    config = function(_, opts)
        local spelunk = require("spelunk")
        local markmgr = require("spelunk.markmgr")
        local set = require("spelunk.config").set_keymap

        -- Display filename and line (default) and optionally the bookmark name
        spelunk.display_function = function(mark)
            local mark_idx = nil
            local mark_name = nil

            for i, mark_ in ipairs(markmgr.physical_stack(spelunk.get_current_stack_index()).bookmarks) do
                if mark_.file == mark.file and mark_.line == mark.line then
                    mark_idx = i
                    break
                end
            end

            if mark_idx then
                mark_name = markmgr.get_mark_meta(spelunk.get_current_stack_index(), mark_idx, "name")
            end

            if mark_name then
                return string.format("%s:%d [%s]", spelunk.filename_formatter(mark.file), mark.line, mark_name)
            end

            return string.format("%s:%d", spelunk.filename_formatter(mark.file), mark.line)
        end

        -- Give the bookmark on the line you're on a name
        local add_mark_name = function()
            local line = vim.fn.line(".")
            local mark_idx = markmgr.get_mark_idx_from_line(
                spelunk.get_current_stack_index(),
                vim.api.nvim_buf_get_name(0),
                line
            )
            if not mark_idx then
                vim.notify(
                    string.format("[spelunk.nvim] Line %d does not have a bookmark", line),
                    vim.log.levels.ERROR
                )
                return
            end
            local name = vim.fn.input("[spelunk.nvim] Name current bookmark: ")
            spelunk.add_mark_meta(spelunk.get_current_stack_index(), mark_idx, "name", name)
        end

        -- Set keymap
        set("<leader>bm", add_mark_name, "[spelunk.nvim] Name current bookmark")

        spelunk.setup(opts)
    end
}
```

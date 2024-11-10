local M = {}

local default_config = {
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
		bookmark_up = '<C-k>',
		goto_bookmark = '<CR>',
		goto_bookmark_hsplit = 'x',
		goto_bookmark_vsplit = 'v',
		delete_bookmark = 'd',
		next_stack = '<Tab>',
		previous_stack = '<S-Tab>',
		new_stack = 'n',
		delete_stack = 'D',
		edit_stack = 'E',
		close = 'q',
		help = 'h',
	},
	enable_persist = false,
	statusline_prefix = '🔖',
	orientation = 'vertical',
}

---@param target table
---@param defaults table
local function apply_defaults(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			target[key] = value
		end
	end
	return target
end

---@param target table
function M.apply_base_defaults(target)
	apply_defaults(target, default_config.base_mappings)
end

---@param target table
function M.apply_window_defaults(target)
	apply_defaults(target, default_config.window_mappings)
end

---@param key string
---@return any
function M.get_default(key)
	return default_config[key]
end

return M

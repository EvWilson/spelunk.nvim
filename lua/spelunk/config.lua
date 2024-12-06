local M = {}

local skipkey = 'NONE'

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
	enable_status_col_display = false,
}

---@param target table
---@param defaults table
local apply_defaults = function(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			target[key] = value
		end
	end
	return target
end

---@param target table
M.apply_base_defaults = function(target)
	apply_defaults(target, default_config.base_mappings)
end

---@param target table
M.apply_window_defaults = function(target)
	apply_defaults(target, default_config.window_mappings)
end

---@param key string
---@return any
M.get_default = function(key)
	return default_config[key]
end

---@param key string
---@param cmd string | function
---@param description string
M.set_keymap = function(key, cmd, description)
	if key == skipkey then
		return
	end
	vim.keymap.set('n', key, cmd,
		{ desc = description, noremap = true, silent = true })
end

---@param bufnr integer
M.set_buf_keymap = function(bufnr)
	---@param key string
	---@param func string
	---@param description string
	return function(key, func, description)
		if key == skipkey then
			return
		end
		vim.api.nvim_buf_set_keymap(bufnr, 'n', key, func, { noremap = true, silent = true, desc = description })
	end
end


return M

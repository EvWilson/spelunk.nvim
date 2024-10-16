local M = {}

local default_config = {
	base_mappings = {
		toggle = '<leader>bt',
		add = '<leader>ba'
	},
	window_mappings = {
		cursor_down = 'j',
		cursor_up = 'k',
		bookmark_down = '<C-j>',
		bookmark_up = '<C-k>',
		goto_bookmark = '<CR>',
		delete_bookmark = 'd',
		next_stack = '<Tab>',
		previous_stack = '<S-Tab>',
		new_stack = 'n',
		delete_stack = 'D',
		close = 'q',
	}
}

local function apply_defaults(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			target[key] = value
		end
	end
	return target
end

function M.apply_base_defaults(target)
	apply_defaults(target, default_config.base_mappings)
end

function M.apply_window_defaults(target)
	apply_defaults(target, default_config.window_mappings)
end

return M

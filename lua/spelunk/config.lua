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

function M.persist_focus(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local group_name = string.format('SpelunkPersistFocus_%d', bufnr)

	local focus_cb = function()
		local current_buf = vim.api.nvim_get_current_buf()
		if current_buf ~= bufnr then
			local windows = vim.api.nvim_list_wins()
			local target_win
			for _, win in ipairs(windows) do
				if vim.api.nvim_win_get_buf(win) == bufnr then
					target_win = win
					break
				end
			end

			if target_win then
				vim.api.nvim_set_current_win(target_win)
			end
		end
	end

	local cleanup_cb = function()
		vim.api.nvim_del_augroup_by_name(group_name)
	end

	local create_cb = function()
		focus_cb()
		vim.api.nvim_create_augroup(group_name, { clear = true })
		vim.api.nvim_create_autocmd('WinEnter', {
			group = group_name,
			callback = focus_cb,
		})

		vim.api.nvim_create_autocmd('BufDelete', {
			group = group_name,
			buffer = bufnr,
			callback = cleanup_cb,
		})
	end

	create_cb()

	return create_cb, cleanup_cb
end

return M

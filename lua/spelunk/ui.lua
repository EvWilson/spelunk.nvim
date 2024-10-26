local popup = require('plenary.popup')

local M = {}

---@type integer
local window_id = -1
---@type integer
local preview_window_id = -1
---@type integer
local help_window_id = -1

local window_config

local focus_cb
local unfocus_cb

local border_chars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }

local width_portion = math.floor(vim.o.columns / 20)
local standard_width = math.floor(width_portion * 8)
local standard_height = math.floor(vim.o.lines * 0.7)
local bookmark_slot = {
	line = math.floor(vim.o.lines / 2) - math.floor(standard_height / 2),
	col = width_portion
}
local preview_slot = {
	line = math.floor(vim.o.lines / 2) - math.floor(standard_height / 2),
	col = width_portion * 11
}
local help_slot = {
	line = math.floor(vim.o.lines / 2) - math.floor(standard_height / 2) - 2,
	col = width_portion * 6
}

---@param id integer
local function window_ready(id)
	return id and id ~= -1 and vim.api.nvim_win_is_valid(id)
end

---@param win_id integer
---@param cleanup function
local function persist_focus(win_id, cleanup)
	local bufnr = vim.api.nvim_win_get_buf(win_id)
	local group_name = string.format('SpelunkPersistFocus_%d', bufnr)

	local focus = function()
		local cb = function()
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
		vim.api.nvim_create_augroup(group_name, { clear = true })
		vim.api.nvim_create_autocmd('WinEnter', {
			group = group_name,
			callback = cb,
			desc = 'spelunk.nvim hold focus'
		})
	end

	local unfocus = function()
		vim.api.nvim_del_augroup_by_name(group_name)
	end

	focus()

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win_id),
		callback = cleanup,
		desc = 'spelunk.nvim cleanup window exit',
	})

	return focus, unfocus
end

---@param filename string
---@param start_line integer
---@param end_line integer
---@return string[]
local function read_lines(filename, start_line, end_line)
	local ok, lines = pcall(vim.fn.readfile, filename)
	if not ok then
		error("[spelunk.nvim] could not read file: " .. filename)
		return {}
	end

	start_line = math.max(1, start_line)
	end_line = math.min(end_line, #lines)
	if end_line < start_line then
		error("[spelunk.nvim] end line must be greater than or equal to start line")
		return {}
	end

	local result = {}
	for i = start_line, end_line do
		table.insert(result, lines[i])
	end
	return result
end

function M.setup(window_cfg)
	window_config = window_cfg
end

---@param opts CreateWinOpts
local function create_window(opts)
	local bufnr = vim.api.nvim_create_buf(false, true)
	local win_id = popup.create(bufnr, {
		title = opts.title,
		line = opts.line,
		col = opts.col,
		minwidth = standard_width,
		minheight = standard_height,
		borderchars = border_chars,
	})
	vim.api.nvim_set_option_value('wrap', false, { win = win_id })
	vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
	return bufnr, win_id
end

function M.show_help()
	unfocus_cb()

	local bufnr, win_id = create_window({
		title = "Help - exit with 'q'",
		col = help_slot.col,
		line = help_slot.line
	})
	local content = {
		'Cursor down       ' .. window_config.cursor_down,
		'Cursor up         ' .. window_config.cursor_up,
		'Bookmark down     ' .. window_config.bookmark_down,
		'Bookmark up       ' .. window_config.bookmark_up,
		'Go to bookmark    ' .. window_config.goto_bookmark,
		'Delete bookmark   ' .. window_config.delete_bookmark,
		'Next stack        ' .. window_config.next_stack,
		'Previous stack    ' .. window_config.previous_stack,
		'New stack         ' .. window_config.new_stack,
		'Delete stack      ' .. window_config.delete_stack,
		'Close             ' .. window_config.close,
		'Help              ' .. 'h',
	}
	vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
	vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
	help_window_id = win_id
	vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', ':lua require("spelunk").close_help()<CR>',
		{ noremap = true, silent = true })

	local _, _ = persist_focus(win_id, function()
		vim.api.nvim_del_augroup_by_name(string.format('SpelunkPersistFocus_%d', bufnr))
		vim.api.nvim_win_close(help_window_id, true)
		help_window_id = -1
		focus_cb()
	end
	)
end

function M.close_help()
	vim.api.nvim_win_close(help_window_id, true)
end

function M.create_windows()
	local bufnr, win_id = create_window({
		title = "Bookmarks",
		col = bookmark_slot.col,
		line = bookmark_slot.line
	})
	window_id = win_id

	local _, prev_id = create_window({
		title = "Preview",
		col = preview_slot.col,
		line = preview_slot.line
	})
	preview_window_id = prev_id

	-- Set up keymaps for navigation within the window
	local function setkey(key, func)
		vim.api.nvim_buf_set_keymap(bufnr, 'n', key, func, { noremap = true, silent = true })
	end
	setkey(window_config.cursor_down, ':lua require("spelunk").move_cursor(1)<CR>')
	setkey(window_config.cursor_up, ':lua require("spelunk").move_cursor(-1)<CR>')
	setkey(window_config.bookmark_down, ':lua require("spelunk").move_bookmark(1)<CR>')
	setkey(window_config.bookmark_up, ':lua require("spelunk").move_bookmark(-1)<CR>')
	setkey(window_config.goto_bookmark, ':lua require("spelunk").goto_selected_bookmark()<CR>')
	setkey(window_config.delete_bookmark, ':lua require("spelunk").delete_selected_bookmark()<CR>')
	setkey(window_config.next_stack, ':lua require("spelunk").next_stack()<CR>')
	setkey(window_config.previous_stack, ':lua require("spelunk").prev_stack()<CR>')
	setkey(window_config.new_stack, ':lua require("spelunk").new_stack()<CR>')
	setkey(window_config.delete_stack, ':lua require("spelunk").delete_current_stack()<CR>')
	setkey(window_config.close, ':lua require("spelunk").close_windows()<CR>')
	setkey('h', ':lua require("spelunk").show_help()<CR>')

	focus_cb, unfocus_cb = persist_focus(win_id, function()
		if window_ready(window_id) then
			vim.api.nvim_win_close(window_id, true)
			window_id = -1
		end
		-- Defer preview window cleanup, as running it concurrently to main window
		-- causes it to not fire
		vim.schedule(function()
			if window_ready(preview_window_id) then
				vim.api.nvim_win_close(preview_window_id, true)
				preview_window_id = -1
			end
		end)
	end)

	return bufnr
end

---@param opts UpdateWinOpts
local function update_preview(opts)
	local bookmark = opts.bookmark
	if not window_ready(preview_window_id) or not bookmark then
		return
	end
	local bufnr = vim.api.nvim_win_get_buf(preview_window_id)
	vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
	local lines = read_lines(bookmark.file, math.max(1, bookmark.line - (standard_height / 2)),
		bookmark.line + (standard_height / 2))
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

	-- Highlight the bookmarked line
	vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
	vim.api.nvim_buf_add_highlight(bufnr, -1, 'Search', math.floor(standard_height / 2), 0, -1)
end

---@param opts UpdateWinOpts
function M.update_window(opts)
	if not window_ready(window_id) then
		return
	end

	local bufnr = vim.api.nvim_win_get_buf(window_id)
	vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
	local content = { 'Current stack: ' .. opts.title, unpack(opts.lines) }
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
	vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

	-- Move cursor to the selected line
	local offset
	if #opts.lines > 0 then
		offset = 1
	else
		offset = 0
	end
	vim.api.nvim_win_set_cursor(window_id, { opts.cursor_index + offset, 0 })

	update_preview(opts)
end

---@param opts UpdateWinOpts
function M.toggle_window(opts)
	if window_ready(window_id) then
		M.close_windows()
	else
		local _ = M.create_windows()
		M.update_window(opts)
		vim.api.nvim_set_current_win(window_id)
	end
end

function M.close_windows()
	if window_ready(window_id) then
		vim.api.nvim_win_close(window_id, true)
		window_id = -1
	end
end

return M

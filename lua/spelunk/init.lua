local ui = require('spelunk.ui')
local persist = require('spelunk.persistence')
local marks = require('spelunk.mark')
local tele = require('spelunk.telescope')
local util = require('spelunk.util')

local M = {}

---@type VirtualStack[]
local default_stacks = {
	{ name = 'Default', bookmarks = {} }
}
---@type VirtualStack[]
local bookmark_stacks
---@type integer
local current_stack_index = 1
---@type integer
local cursor_index = 1

local window_config

---@type boolean
local enable_persist

---@type string
local statusline_prefix

---@type boolean
local show_status_col

---@return VirtualStack[]
local get_stacks = function()
	return bookmark_stacks
end

---@return VirtualStack
local current_stack = function()
	return bookmark_stacks[current_stack_index]
end

---@return VirtualBookmark
local current_bookmark = function()
	return bookmark_stacks[current_stack_index].bookmarks[cursor_index]
end

---@param abspath string
---@return string
M.filename_formatter = function(abspath)
	return vim.fn.fnamemodify(abspath, ':~:.')
end

---@param mark VirtualBookmark | PhysicalBookmark | FullBookmark
---@return string
M.display_function = function(mark)
	return string.format('%s:%d', M.filename_formatter(mark.file), mark.line)
end

---@return integer
local max_stack_size = function()
	local max = 0
	for _, stack in ipairs(bookmark_stacks) do
		local size = #stack.bookmarks
		if size > max then
			max = size
		end
	end
	return max
end

---@return UpdateWinOpts
local get_win_update_opts = function()
	local lines = {}
	for _, vmark in ipairs(current_stack().bookmarks) do
		table.insert(lines, M.display_function(vmark))
	end
	return {
		cursor_index = cursor_index,
		title = current_stack().name,
		lines = lines,
		bookmark = current_bookmark(),
		max_stack_size = max_stack_size(),
	}
end

---@param updated_indices boolean
local update_window = function(updated_indices)
	if updated_indices and show_status_col then
		marks.update_indices(current_stack())
	end
	ui.update_window(get_win_update_opts())
end

---@param file string
---@param line integer
---@param split string | nil
local goto_position = function(file, line, col, split)
	if vim.fn.filereadable(file) ~= 1 then
		vim.notify('[spelunk.nvim] file being navigated to does not seem to exist: ' .. file)
		return
	end
	if not split then
		vim.api.nvim_command('edit ' .. file)
		vim.api.nvim_win_set_cursor(0, { line, col })
	elseif split == 'vertical' then
		vim.api.nvim_command('vsplit ' .. file)
		local new_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(new_win, { line, col })
	elseif split == 'horizontal' then
		vim.api.nvim_command('split ' .. file)
		local new_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(new_win, { line, col })
	else
		vim.notify('[spelunk.nvim] goto_position passed unsupported split: ' .. split)
	end
end

function M.toggle_window()
	ui.toggle_window(get_win_update_opts())
end

function M.close_windows()
	ui.close_windows()
end

function M.show_help()
	ui.show_help()
end

function M.close_help()
	ui.close_help()
end

function M.add_bookmark()
	if ui.is_open() then
		vim.notify('[spelunk.nvim] Cannot create bookmark while UI is open')
		return
	end
	local currstack = current_stack()
	table.insert(currstack.bookmarks, marks.set_mark_current_pos(#currstack.bookmarks + 1))
	vim.notify(string.format("[spelunk.nvim] Bookmark added to stack '%s': %s:%d:%d",
		currstack.name, vim.fn.expand('%:p'), vim.fn.line('.'), vim.fn.col('.')))
	update_window(true)
	M.persist()
end

---@param direction 1 | -1
function M.move_cursor(direction)
	local bookmarks = current_stack().bookmarks
	cursor_index = cursor_index + direction
	if cursor_index < 1 then
		cursor_index = math.max(#bookmarks, 1)
	elseif cursor_index > #bookmarks then
		cursor_index = 1
	end
	update_window(true)
end

---@param direction 1 | -1
function M.move_bookmark(direction)
	if direction ~= 1 and direction ~= -1 then
		vim.notify('[spelunk.nvim] move_bookmark passed invalid direction')
		return
	end
	local curr_stack = current_stack()
	if #current_stack().bookmarks < 2 then
		return
	end
	local new_idx = cursor_index + direction
	if new_idx < 1 or new_idx > #curr_stack.bookmarks then
		return
	end
	local curr_mark = current_bookmark()
	local tmp_new = bookmark_stacks[current_stack_index].bookmarks[new_idx]
	bookmark_stacks[current_stack_index].bookmarks[cursor_index] = tmp_new
	bookmark_stacks[current_stack_index].bookmarks[new_idx] = curr_mark
	M.move_cursor(direction)
	M.persist()
end

---@param close boolean
---@param split string | nil
local function goto_bookmark(close, split)
	local bookmarks = current_stack().bookmarks
	local mark = marks.virt_to_physical(current_bookmark())
	if cursor_index > 0 and cursor_index <= #bookmarks then
		if close then
			M.close_windows()
		end
		vim.schedule(function()
			goto_position(mark.file, mark.line, mark.col, split)
		end)
	end
end

---@param idx integer
function M.goto_bookmark_at_index(idx)
	if idx < 1 or idx > #current_stack().bookmarks then
		vim.notify('[spelunk.nvim] Given invalid index: ' .. idx)
		return
	end
	cursor_index = idx
	goto_bookmark(true)
end

function M.goto_selected_bookmark()
	goto_bookmark(true)
end

function M.goto_selected_bookmark_horizontal_split()
	goto_bookmark(true, 'horizontal')
end

function M.goto_selected_bookmark_vertical_split()
	goto_bookmark(true, 'vertical')
end

function M.delete_selected_bookmark()
	local bookmarks = current_stack().bookmarks
	if not bookmarks[cursor_index] then
		return
	end
	marks.delete_mark(bookmarks[cursor_index])
	table.remove(bookmarks, cursor_index)
	if cursor_index > #bookmarks and #bookmarks ~= 0 then
		cursor_index = #bookmarks
	end
	update_window(true)
	M.persist()
end

---@param direction 1 | -1
function M.select_and_goto_bookmark(direction)
	if ui.is_open() then
		return
	end
	if #current_stack().bookmarks == 0 then
		vim.notify('[spelunk.nvim] No bookmarks to go to')
		return
	end
	M.move_cursor(direction)
	goto_bookmark(false)
end

function M.delete_current_stack()
	if #bookmark_stacks < 2 then
		vim.notify('[spelunk.nvim] Cannot delete a stack when you have less than two')
		return
	end
	if not current_stack() then
		return
	end
	marks.delete_stack(current_stack())
	table.remove(bookmark_stacks, current_stack_index)
	current_stack_index = 1
	update_window(false)
	M.persist()
end

function M.edit_current_stack()
	local stack = current_stack()
	if not stack then
		return
	end
	local name = vim.fn.input('[spelunk.nvim] Enter new name for the stack: ', stack.name)
	if name == '' then
		return
	end
	current_stack().name = name
	update_window(false)
	M.persist()
end

function M.next_stack()
	current_stack_index = current_stack_index % #bookmark_stacks + 1
	cursor_index = 1
	update_window(false)
end

function M.prev_stack()
	current_stack_index = (current_stack_index - 2) % #bookmark_stacks + 1
	cursor_index = 1
	update_window(false)
end

function M.new_stack()
	local name = vim.fn.input('[spelunk.nvim] Enter name for new stack: ')
	if name and name ~= '' then
		table.insert(bookmark_stacks, { name = name, bookmarks = {} })
		current_stack_index = #bookmark_stacks
		cursor_index = 1
		update_window(false)
	end
	M.persist()
end

function M.persist()
	if enable_persist then
		persist.save(marks.virt_to_physical_stack(bookmark_stacks))
	end
end

---@return FullBookmark[]
function M.all_full_marks()
	local data = {}
	for _, stack in ipairs(bookmark_stacks) do
		for _, vmark in ipairs(stack.bookmarks) do
			local mark = marks.virt_to_physical(vmark)
			table.insert(data, {
				stack = stack.name,
				file = mark.file,
				line = mark.line,
				col = mark.col,
				meta = mark.meta,
			})
		end
	end
	return data
end

function M.search_marks()
	if not tele then
		vim.notify('[spelunk.nvim] Install telescope.nvim to search marks')
		return
	end
	local data = {}
	for _, stack in ipairs(bookmark_stacks) do
		for _, vmark in ipairs(stack.bookmarks) do
			local copy = util.copy_tbl(vmark)
			copy.stack = stack.name
			table.insert(data, copy)
		end
	end
	tele.search_marks('[spelunk.nvim] Bookmarks', data, goto_position)
end

---@return FullBookmark[]
function M.current_full_marks()
	local data = {}
	local stack = current_stack()
	for _, vmark in ipairs(stack.bookmarks) do
		local mark = marks.virt_to_physical(vmark)
		table.insert(data, {
			stack = stack.name,
			file = mark.file,
			line = mark.line,
			col = mark.col,
			meta = mark.meta,
		})
	end
	return data
end

function M.search_current_marks()
	if not tele then
		vim.notify('[spelunk.nvim] Install telescope.nvim to search current marks')
		return
	end
	local data = {}
	local stack = current_stack()
	for _, vmark in ipairs(stack.bookmarks) do
		local copy = util.copy_tbl(vmark)
		copy.stack = stack.name
		table.insert(data, copy)
	end
	tele.search_marks('[spelunk.nvim] Current Stack', data, goto_position)
end

function M.search_stacks()
	if not tele then
		vim.notify('[spelunk.nvim] Install telescope.nvim to search stacks')
		return
	end
	---@param stack PhysicalStack
	local cb = function(stack)
		local stack_idx
		for i, s in ipairs(bookmark_stacks) do
			if s.name == stack.name then
				stack_idx = i
			end
		end
		if not stack_idx then
			return
		end
		current_stack_index = stack_idx
		M.toggle_window()
	end
	tele.search_stacks('[spelunk.nvim] Stacks', bookmark_stacks, cb)
end

---@return string
function M.statusline()
	local count = 0
	local path = vim.fn.expand('%:p')
	for _, stack in ipairs(bookmark_stacks) do
		for _, vmark in ipairs(stack.bookmarks) do
			local mark = marks.virt_to_physical(vmark)
			if mark.file == path then
				count = count + 1
			end
		end
	end
	return statusline_prefix .. ' ' .. count
end

---@param vmarks VirtualBookmark[]
local open_marks_qf = function(vmarks)
	local qf_items = {}
	for _, vmark in ipairs(vmarks) do
		local mark = marks.virt_to_physical(vmark)
		table.insert(qf_items, {
			bufnr = vmark.bufnr,
			lnum = mark.line,
			col = mark.col,
			text = vim.fn.getline(mark.line),
			type = '',
		})
	end
	vim.fn.setqflist(qf_items, 'r')
	vim.cmd('copen')
end

M.qf_all_marks = function()
	local vmarks = {}
	for _, vstack in ipairs(bookmark_stacks) do
		for _, vmark in ipairs(vstack.bookmarks) do
			table.insert(vmarks, vmark)
		end
	end
	open_marks_qf(vmarks)
end

M.qf_current_marks = function()
	local vmarks = {}
	for _, vmark in ipairs(current_stack().bookmarks) do
		table.insert(vmarks, vmark)
	end
	open_marks_qf(vmarks)
end

---@param field string
---@param val any
M.add_mark_meta = function(field, val)
	current_bookmark().meta[field] = val
end

---@param mark VirtualBookmark | PhysicalBookmark
---@return any | nil
M.get_mark_meta = function(mark, field)
	return mark.meta[field]
end

function M.setup(c)
	local conf = c or {}
	local cfg = require('spelunk.config')
	local base_config = conf.base_mappings or {}
	cfg.apply_base_defaults(base_config)
	window_config = conf.window_mappings or {}
	cfg.apply_window_defaults(window_config)
	ui.setup(base_config, window_config, conf.cursor_character or cfg.get_default('cursor_character'))

	require('spelunk.layout').setup(conf.orientation or cfg.get_default('orientation'))

	show_status_col = conf.enable_status_col_display or cfg.get_default('enable_status_col_display')

	-- This does a whole lot of work on setup, and can potentially delay the loading of other plugins
	-- In the worst case, this has blocked the loading of LSP servers, possibly by timeout
	-- Adding something like a `lazy.nvim` `VeryLazy` event spec doesn't work in all cases,
	-- e.g. when the Lualine integration is enabled, it forces it to load up anyway
	-- This seems to delay things just long enough to get it to play nicely with others
	vim.schedule(function()
		-- Load saved bookmarks, if enabled and available
		-- Otherwise, set defaults
		---@type PhysicalStack[] | nil
		local physical_stacks
		enable_persist = conf.enable_persist or cfg.get_default('enable_persist')
		if enable_persist then
			physical_stacks = persist.load()
		end
		if not physical_stacks then
			physical_stacks = default_stacks
		end

		bookmark_stacks = marks.setup(physical_stacks, show_status_col, enable_persist, M.persist, get_stacks)

		-- Configure the prefix to use for the lualine integration
		statusline_prefix = conf.statusline_prefix or cfg.get_default('statusline_prefix')

		local set = cfg.set_keymap
		set(base_config.toggle, M.toggle_window, '[spelunk.nvim] Toggle UI')
		set(base_config.add, M.add_bookmark, '[spelunk.nvim] Add bookmark')
		set(base_config.next_bookmark, ':lua require("spelunk").select_and_goto_bookmark(1)<CR>',
			'[spelunk.nvim] Go to next bookmark')
		set(base_config.prev_bookmark, ':lua require("spelunk").select_and_goto_bookmark(-1)<CR>',
			'[spelunk.nvim] Go to previous bookmark')

		-- Register telescope extension, only if telescope itself is loaded already
		local telescope_loaded, telescope = pcall(require, 'telescope')
		if not telescope_loaded or not telescope then
			return
		end
		telescope.load_extension('spelunk')
		set(base_config.search_bookmarks, telescope.extensions.spelunk.marks,
			'[spelunk.nvim] Fuzzy find bookmarks')
		set(base_config.search_current_bookmarks, telescope.extensions.spelunk.current_marks,
			'[spelunk.nvim] Fuzzy find bookmarks in current stack')
		set(base_config.search_stacks, telescope.extensions.spelunk.stacks, '[spelunk.nvim] Fuzzy find stacks')
	end)
end

return M

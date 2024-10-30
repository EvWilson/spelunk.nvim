local ui = require('spelunk.ui')
local persist = require('spelunk.persistence')

local M = {}

---@type BookmarkStack
local default_stacks = {
	{ name = 'Default', bookmarks = {} }
}
---@type BookmarkStack
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

---@param tbl table
local function tbllen(tbl)
	local count = 0
	for _ in pairs(tbl) do count = count + 1 end
	return count
end

local function current_stack()
	return bookmark_stacks[current_stack_index]
end

local function current_bookmark()
	return bookmark_stacks[current_stack_index].bookmarks[cursor_index]
end

---@return UpdateWinOpts
local function get_win_update_opts()
	local lines = {}
	for i, bookmark in ipairs(bookmark_stacks[current_stack_index].bookmarks) do
		local prefix = i == cursor_index and '> ' or '  '
		local display = string.format('%s%s:%d', prefix, vim.fn.fnamemodify(bookmark.file, ':~:.'), bookmark.line)
		table.insert(lines, display)
	end
	return {
		cursor_index = cursor_index,
		title = current_stack().name,
		lines = lines,
		bookmark = current_bookmark(),
	}
end

local function update_window()
	ui.update_window(get_win_update_opts())
end

---@param file string
---@param line integer
---@param split string | nil
local function goto_position(file, line, split)
	if not split then
		vim.cmd('edit +' .. line .. ' ' .. file)
	elseif split == 'vertical' then
		vim.cmd('vsplit +' .. line .. ' ' .. file)
	elseif split == 'horizontal' then
		vim.cmd('split +' .. line .. ' ' .. file)
	else
		print('[spelunk.nvim] goto_position passed unsupported split: ' .. split)
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
	local current_file = vim.fn.expand('%:p')
	local current_line = vim.fn.line('.')
	table.insert(bookmark_stacks[current_stack_index].bookmarks, { file = current_file, line = current_line })
	print("[spelunk.nvim] Bookmark added to stack '" ..
		bookmark_stacks[current_stack_index].name .. "': " .. current_file .. ":" .. current_line)
	update_window()
	M.persist()
end

---@param direction 1 | -1
function M.move_cursor(direction)
	local bookmarks = bookmark_stacks[current_stack_index].bookmarks
	cursor_index = cursor_index + direction
	if cursor_index < 1 then
		cursor_index = math.max(#bookmarks, 1)
	elseif cursor_index > #bookmarks then
		cursor_index = 1
	end
	update_window()
end

---@param direction 1 | -1
function M.move_bookmark(direction)
	if direction ~= 1 and direction ~= -1 then
		print('[spelunk.nvim] move_bookmark passed invalid direction')
		return
	end
	local curr_stack = current_stack()
	if tbllen(current_stack().bookmarks) < 2 then
		return
	end
	local new_idx = cursor_index + direction
	if new_idx < 1 or new_idx > tbllen(curr_stack.bookmarks) then
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
	local bookmarks = bookmark_stacks[current_stack_index].bookmarks
	if cursor_index > 0 and cursor_index <= #bookmarks then
		if close then
			M.close_windows()
		end
		vim.schedule(function()
			goto_position(bookmarks[cursor_index].file, bookmarks[cursor_index].line, split)
		end)
	end
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
	local bookmarks = bookmark_stacks[current_stack_index].bookmarks
	if not bookmarks[cursor_index] then
		return
	end
	table.remove(bookmarks, cursor_index)
	if cursor_index > #bookmarks and #bookmarks ~= 0 then
		cursor_index = #bookmarks
	end
	update_window()
	M.persist()
end

---@param direction 1 | -1
function M.select_and_goto_bookmark(direction)
	M.move_cursor(direction)
	goto_bookmark(false)
end

function M.delete_current_stack()
	if tbllen(bookmark_stacks) < 2 then
		print('[spelunk.nvim] Cannot delete a stack when you have less than two')
		return
	end
	if not bookmark_stacks[current_stack_index] then
		return
	end
	table.remove(bookmark_stacks, current_stack_index)
	current_stack_index = 1
	update_window()
	M.persist()
end

function M.edit_current_stack()
	local stack = bookmark_stacks[current_stack_index]
	if not stack then
		return
	end
	local name = vim.fn.input('[spelunk.nvim] Enter new name for the stack: ', stack.name)
	bookmark_stacks[current_stack_index].name = name
	update_window()
	M.persist()
end

function M.next_stack()
	current_stack_index = current_stack_index % #bookmark_stacks + 1
	cursor_index = 1
	update_window()
end

function M.prev_stack()
	current_stack_index = (current_stack_index - 2) % #bookmark_stacks + 1
	cursor_index = 1
	update_window()
end

function M.new_stack()
	local name = vim.fn.input('[spelunk.nvim] Enter name for new stack: ')
	if name and name ~= '' then
		table.insert(bookmark_stacks, { name = name, bookmarks = {} })
		current_stack_index = #bookmark_stacks
		cursor_index = 1
		update_window()
	end
	M.persist()
end

function M.persist()
	if enable_persist then
		persist.save(bookmark_stacks)
	end
end

function M.search_marks()
	local data = {}
	for _, stack in ipairs(bookmark_stacks) do
		for _, mark in ipairs(stack.bookmarks) do
			table.insert(data, {
				stack = stack.name,
				file = mark.file,
				line = mark.line,
			})
		end
	end
	require('spelunk.telescope').search_stacks('[spelunk.nvim] Bookmarks', data, goto_position)
end

function M.search_current_marks()
	local data = {}
	local stack = current_stack()
	for _, mark in ipairs(stack.bookmarks) do
		table.insert(data, {
			stack = stack.name,
			file = mark.file,
			line = mark.line,
		})
	end
	require('spelunk.telescope').search_stacks('[spelunk.nvim] Current Stack', data, goto_position)
end

---@return string
function M.statusline()
	local count = 0
	local path = vim.fn.expand('%:p')
	for _, stack in ipairs(bookmark_stacks) do
		for _, mark in ipairs(stack.bookmarks) do
			if mark.file == path then
				count = count + 1
			end
		end
	end
	return statusline_prefix .. ' ' .. count
end

function M.setup(c)
	local conf = c or {}
	local cfg = require('spelunk.config')
	local base_config = conf.base_mappings or {}
	cfg.apply_base_defaults(base_config)
	window_config = conf.window_mappings or {}
	cfg.apply_window_defaults(window_config)
	ui.setup(base_config, window_config)

	-- Load saved bookmarks, if enabled and available
	-- Otherwise, set defaults
	enable_persist = conf.enable_persist or cfg.get_default('enable_persist')
	if enable_persist then
		local saved = persist.load()
		if saved then
			bookmark_stacks = saved
		end
	end
	if not bookmark_stacks then
		bookmark_stacks = default_stacks
	end

	-- Configure the prefix to use for the lualine integration
	statusline_prefix = conf.statusline_prefix or cfg.get_default('statusline_prefix')

	local set = function(key, cmd, description)
		vim.keymap.set('n', key, cmd,
			{ desc = description, noremap = true, silent = true })
	end
	set(base_config.toggle, M.toggle_window, '[spelunk.nvim] Toggle UI')
	set(base_config.add, M.add_bookmark, '[spelunk.nvim] Add bookmark')
	set(base_config.next_bookmark, ':lua require("spelunk").select_and_goto_bookmark(1)<CR>',
		'[spelunk.nvim] Go to next bookmark')
	set(base_config.prev_bookmark, ':lua require("spelunk").select_and_goto_bookmark(-1)<CR>',
		'[spelunk.nvim] Go to previous bookmark')

	-- Register telescope extension, only if telescope itself is loaded already
	local telescope_loaded, tele = pcall(require, 'telescope')
	if not telescope_loaded then
		return
	end
	tele.load_extension('spelunk')
	set(base_config.search_bookmarks, tele.extensions.spelunk.marks,
		'[spelunk.nvim] Fuzzy find bookmarks')
	set(base_config.search_current_bookmarks, tele.extensions.spelunk.current_marks,
		'[spelunk.nvim] Fuzzy find bookmarks in current stack')
end

return M

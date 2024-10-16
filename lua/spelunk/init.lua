local ui = require('spelunk.ui')

local M = {}

---@class Bookmark
---@field file string
---@field line integer

---@type table<string, Bookmark[]>
local bookmark_stacks = {
	{ name = "Default", bookmarks = {} }
}
---@type integer
local current_stack_index = 1
---@type integer
local cursor_index = 1

local window_config = nil

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
		local display = string.format("%s%s:%d", prefix, vim.fn.fnamemodify(bookmark.file, ':~:.'), bookmark.line)
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
	print("[spelunk] Bookmark added to stack '" ..
		bookmark_stacks[current_stack_index].name .. "': " .. current_file .. ":" .. current_line)
	update_window()
end

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

---@param direction integer
function M.move_bookmark(direction)
	if direction ~= 1 and direction ~= -1 then
		print('[spelunk] move_bookmark passed invalid direction')
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
end

function M.goto_selected_bookmark()
	local bookmarks = bookmark_stacks[current_stack_index].bookmarks
	if bookmarks[cursor_index] then
		local bookmark = bookmarks[cursor_index]
		ui.close_windows()
		vim.cmd('edit +' .. bookmark.line .. ' ' .. bookmark.file)
	end
end

function M.delete_selected_bookmark()
	local bookmarks = bookmark_stacks[current_stack_index].bookmarks
	if not bookmarks[cursor_index] then
		return
	end
	table.remove(bookmarks, cursor_index)
	if cursor_index > #bookmarks then
		cursor_index = #bookmarks
	end
	update_window()
end

function M.delete_current_stack()
	if tbllen(bookmark_stacks) < 2 then
		print('[spelunk] Cannot delete a stack when you have less than two')
		return
	end
	if not bookmark_stacks[current_stack_index] then
		return
	end
	table.remove(bookmark_stacks, current_stack_index)
	current_stack_index = 1
	update_window()
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
	local name = vim.fn.input("[spelunk] Enter name for new stack: ")
	if name and name ~= "" then
		table.insert(bookmark_stacks, { name = name, bookmarks = {} })
		current_stack_index = #bookmark_stacks
		cursor_index = 1
		update_window()
	end
end

function M.setup(config)
	local cfg_helpers = require('spelunk.config')
	local base_config = (config or {}).base_mappings or {}
	cfg_helpers.apply_base_defaults(base_config)
	window_config = (config or {}).window_mappings or {}
	cfg_helpers.apply_window_defaults(window_config)
	ui.setup(window_config)

	local set = vim.keymap.set
	set('n', base_config.toggle, ':lua require("spelunk").toggle_window()<CR>',
		{ noremap = true, silent = true })
	set('n', base_config.add, ':lua require("spelunk").add_bookmark()<CR>',
		{ noremap = true, silent = true })
end

return M

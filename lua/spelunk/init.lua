local ui = require("spelunk.ui")
local persist = require("spelunk.persistence")
---@diagnostic disable-next-line
local tele = require("spelunk.telescope")
local markmgr = require("spelunk.markmgr")

local M = {}

---@type PhysicalStack[]
local default_stacks = {
	{ name = "Default", bookmarks = {} },
}
---@type integer
local current_stack_index = 1
---@type integer
local cursor_index = 1

---@type any
local window_config

---@type boolean
local enable_persist
---@type string
local statusline_prefix
---@type boolean
local show_status_col

---@param abspath string
---@return string
M.filename_formatter = function(abspath)
	return vim.fn.fnamemodify(abspath, ":~:.")
end

---@param mark PhysicalBookmark | FullBookmark
---@return string
M.display_function = function(mark)
	return string.format("%s:%d", M.filename_formatter(mark.file), mark.line)
end

---@return UpdateWinOpts
local get_win_update_opts = function()
	---@type string[]
	local lines = {}
	for _, mark in ipairs(markmgr.physical_stack(current_stack_index).bookmarks) do
		vim.notify("EAW mark in get update opts: " .. vim.inspect(mark))
		table.insert(lines, M.display_function(mark))
	end
	---@type PhysicalBookmark | nil
	local mark
	if markmgr.valid_indices(current_stack_index, cursor_index) then
		mark = markmgr.physical_mark(current_stack_index, cursor_index)
	else
		mark = nil
	end
	return {
		cursor_index = cursor_index,
		title = markmgr.get_stack_name(current_stack_index),
		lines = lines,
		bookmark = mark,
		max_stack_size = markmgr.max_stack_len(),
	}
end

---@param updated_indices boolean
local update_window = function(updated_indices)
	if updated_indices and show_status_col then
		markmgr.update_indices(current_stack_index)
	end
	ui.update_window(get_win_update_opts())
end

---@param file string
---@param line integer
---@param split "vertical" | "horizontal" | nil
local goto_position = function(file, line, col, split)
	if vim.fn.filereadable(file) ~= 1 then
		vim.notify("[spelunk.nvim] file being navigated to does not seem to exist: " .. file)
		return
	end
	if not split then
		vim.api.nvim_command("edit " .. file)
		vim.api.nvim_win_set_cursor(0, { line, col })
	elseif split == "vertical" then
		vim.api.nvim_command("vsplit " .. file)
		local new_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(new_win, { line, col })
	elseif split == "horizontal" then
		vim.api.nvim_command("split " .. file)
		local new_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(new_win, { line, col })
	else
		vim.notify("[spelunk.nvim] goto_position passed unsupported split: " .. split)
	end
end

M.toggle_window = function()
	ui.toggle_window(get_win_update_opts())
end

M.close_windows = function()
	ui.close_windows()
end

M.show_help = function()
	ui.show_help()
end

M.close_help = function()
	ui.close_help()
end

M.add_bookmark = function()
	if ui.is_open() then
		vim.notify("[spelunk.nvim] Cannot create bookmark while UI is open")
		return
	end
	markmgr.add_mark_current_pos(current_stack_index)
	update_window(true)
	M.persist()
end

---@param direction 1 | -1
M.move_cursor = function(direction)
	if direction ~= 1 and direction ~= -1 then
		vim.notify("[spelunk.nvim] move_cursor passed invalid direction")
		return
	end
	cursor_index = markmgr.move_mark_idx(current_stack_index, cursor_index, direction)
	update_window(true)
end

---@param direction 1 | -1
M.move_bookmark = function(direction)
	if direction ~= 1 and direction ~= -1 then
		vim.notify("[spelunk.nvim] move_bookmark passed invalid direction")
		return
	end
	markmgr.move_mark_in_stack(current_stack_index, cursor_index, direction)
	M.move_cursor(direction)
	M.persist()
end

---@param close boolean
---@param split "vertical" | "horizontal" | nil
local goto_bookmark = function(close, split)
	if cursor_index > 0 and cursor_index <= markmgr.len_marks(current_stack_index) then
		if close then
			M.close_windows()
		end
		vim.schedule(function()
			local mark = markmgr.physical_mark(current_stack_index, cursor_index)
			goto_position(mark.file, mark.line, mark.col, split)
		end)
	end
end

---@param idx integer
M.goto_bookmark_at_index = function(idx)
	if idx < 1 or idx > markmgr.len_marks(current_stack_index) then
		vim.notify("[spelunk.nvim] Given invalid index: " .. idx)
		return
	end
	cursor_index = idx
	goto_bookmark(true)
end

M.goto_selected_bookmark = function()
	goto_bookmark(true)
end

M.goto_selected_bookmark_horizontal_split = function()
	goto_bookmark(true, "horizontal")
end

M.goto_selected_bookmark_vertical_split = function()
	goto_bookmark(true, "vertical")
end

M.delete_selected_bookmark = function()
	cursor_index = markmgr.delete_mark(current_stack_index, cursor_index)
	update_window(true)
	M.persist()
end

---@param direction 1 | -1
M.select_and_goto_bookmark = function(direction)
	if ui.is_open() then
		return
	end
	if markmgr.len_marks(current_stack_index) == 0 then
		vim.notify("[spelunk.nvim] No bookmarks to go to")
		return
	end
	M.move_cursor(direction)
	goto_bookmark(false)
end

M.delete_current_stack = function()
	markmgr.delete_stack(current_stack_index)
	current_stack_index = 1
	update_window(false)
	M.persist()
end

M.edit_current_stack = function()
	local name =
		vim.fn.input("[spelunk.nvim] Enter new name for the stack: ", markmgr.get_stack_name(current_stack_index))
	if name == "" then
		return
	end
	markmgr.set_stack_name(current_stack_index, name)
	update_window(false)
	M.persist()
end

M.next_stack = function()
	current_stack_index = current_stack_index % markmgr.len_stacks() + 1
	cursor_index = 1
	update_window(false)
end

M.prev_stack = function()
	current_stack_index = (current_stack_index - 2) % markmgr.len_stacks() + 1
	cursor_index = 1
	update_window(false)
end

M.new_stack = function()
	local name = vim.fn.input("[spelunk.nvim] Enter name for new stack: ")
	if name and name ~= "" then
		local new_stack_idx = markmgr.add_stack(name)
		current_stack_index = new_stack_idx
		cursor_index = 1
		update_window(false)
	end
	M.persist()
end

M.persist = function()
	if enable_persist then
		persist.save(markmgr.physical_stacks())
	end
end

---@return FullBookmark[]
M.all_full_marks = function()
	local data = {}
	for _, stack in ipairs(markmgr.physical_stacks()) do
		for _, mark in ipairs(stack.bookmarks) do
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

M.search_marks = function()
	if not tele then
		vim.notify("[spelunk.nvim] Install telescope.nvim to search marks")
		return
	end
	if ui.is_open() then
		vim.notify("[spelunk.nvim] Cannot search with UI open")
		return
	end
	tele.search_marks("[spelunk.nvim] Bookmarks", M.all_full_marks(), goto_position)
end

---@return FullBookmark[]
M.current_full_marks = function()
	local data = {}
	local stack = markmgr.physical_stack(current_stack_index)
	for _, mark in ipairs(stack.bookmarks) do
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

M.search_current_marks = function()
	if not tele then
		vim.notify("[spelunk.nvim] Install telescope.nvim to search current marks")
		return
	end
	if ui.is_open() then
		vim.notify("[spelunk.nvim] Cannot search with UI open")
		return
	end
	tele.search_marks("[spelunk.nvim] Current Stack", M.current_full_marks(), goto_position)
end

M.search_stacks = function()
	if not tele then
		vim.notify("[spelunk.nvim] Install telescope.nvim to search stacks")
		return
	end
	if ui.is_open() then
		vim.notify("[spelunk.nvim] Cannot search with UI open")
		return
	end
	---@param stack_name string
	local cb = function(stack_name)
		local stack_idx = markmgr.stack_idx_for_name(stack_name)
		if stack_idx < 0 then
			return
		end
		current_stack_index = stack_idx
		M.toggle_window()
	end
	tele.search_stacks("[spelunk.nvim] Stacks", markmgr.stack_names(), cb)
end

---@return string
M.statusline = function()
	local path = vim.fn.expand("%:p")
	return statusline_prefix .. " " .. markmgr.instances_of_file(path)
end

---@param marks PhysicalBookmark[]
local open_marks_qf = function(marks)
	local qf_items = {}
	for _, mark in ipairs(marks) do
		table.insert(qf_items, {
			bufnr = vim.fn.bufnr(mark.file),
			lnum = mark.line,
			col = mark.col,
			text = vim.fn.getline(mark.line),
			type = "",
		})
	end
	vim.fn.setqflist(qf_items, "r")
	vim.cmd("copen")
end

M.qf_all_marks = function()
	---@type PhysicalBookmark[]
	local marks = {}
	for _, stack in ipairs(markmgr.physical_stacks()) do
		for _, mark in ipairs(stack.bookmarks) do
			table.insert(marks, mark)
		end
	end
	open_marks_qf(marks)
end

M.qf_current_marks = function()
	---@type PhysicalBookmark[]
	local marks = {}
	for _, mark in ipairs(markmgr.physical_stack(current_stack_index)) do
		table.insert(marks, mark)
	end
	open_marks_qf(marks)
end

---@param stack_idx integer
---@param mark_idx integer
---@param field string
---@param val any
M.add_mark_meta = function(stack_idx, mark_idx, field, val)
	markmgr.add_mark_meta(stack_idx, mark_idx, field, val)
end

---@param stack_idx integer
---@param mark_idx integer
---@param field string
---@return any | nil
M.get_mark_meta = function(stack_idx, mark_idx, field)
	return markmgr.get_mark_meta(stack_idx, mark_idx, field)
end

M.setup = function(c)
	local conf = c or {}
	local cfg = require("spelunk.config")
	local base_config = conf.base_mappings or {}
	cfg.apply_base_defaults(base_config)
	window_config = conf.window_mappings or {}
	cfg.apply_window_defaults(window_config)
	ui.setup(base_config, window_config, conf.cursor_character or cfg.get_default("cursor_character"))

	require("spelunk.layout").setup(conf.orientation or cfg.get_default("orientation"))

	show_status_col = conf.enable_status_col_display or cfg.get_default("enable_status_col_display")

	persist.setup(conf.persist_by_git_branch or cfg.get_default("persist_by_git_branch"))

	-- This does a whole lot of work on setup, and can potentially delay the loading of other plugins
	-- In the worst case, this has blocked the loading of LSP servers, possibly by timeout
	-- Adding something like a `lazy.nvim` `VeryLazy` event spec doesn't work in all cases,
	-- e.g. when the Lualine integration is enabled, it forces it to load up anyway
	-- This seems to delay things just long enough to get it to play nicely with others
	-- vim.schedule(function()
	-- 	-- Load saved bookmarks, if enabled and available
	-- 	-- Otherwise, set defaults
	-- 	---@type PhysicalStack[] | nil
	-- 	local physical_stacks
	-- 	enable_persist = conf.enable_persist or cfg.get_default("enable_persist")
	-- 	if enable_persist then
	-- 		physical_stacks = persist.load()
	-- 	end
	-- 	if not physical_stacks then
	-- 		physical_stacks = default_stacks
	-- 	end
	-- 	markmgr.init(physical_stacks, {
	-- 		persist_enabled = enable_persist,
	-- 		persist_cb = M.persist,
	-- 	}, show_status_col)
	--
	-- 	-- bookmark_stacks = marks.setup(physical_stacks, show_status_col, enable_persist, M.persist, get_stacks)
	--
	-- 	-- Configure the prefix to use for the lualine integration
	-- 	statusline_prefix = conf.statusline_prefix or cfg.get_default("statusline_prefix")
	--
	-- 	local set = cfg.set_keymap
	-- 	set(base_config.toggle, M.toggle_window, "[spelunk.nvim] Toggle UI")
	-- 	set(base_config.add, M.add_bookmark, "[spelunk.nvim] Add bookmark")
	-- 	set(
	-- 		base_config.next_bookmark,
	-- 		':lua require("spelunk").select_and_goto_bookmark(1)<CR>',
	-- 		"[spelunk.nvim] Go to next bookmark"
	-- 	)
	-- 	set(
	-- 		base_config.prev_bookmark,
	-- 		':lua require("spelunk").select_and_goto_bookmark(-1)<CR>',
	-- 		"[spelunk.nvim] Go to previous bookmark"
	-- 	)
	--
	-- 	-- Register telescope extension, only if telescope itself is loaded already
	-- 	local telescope_loaded, telescope = pcall(require, "telescope")
	-- 	if not telescope_loaded or not telescope then
	-- 		return
	-- 	end
	-- 	telescope.load_extension("spelunk")
	-- 	set(base_config.search_bookmarks, telescope.extensions.spelunk.marks, "[spelunk.nvim] Fuzzy find bookmarks")
	-- 	set(
	-- 		base_config.search_current_bookmarks,
	-- 		telescope.extensions.spelunk.current_marks,
	-- 		"[spelunk.nvim] Fuzzy find bookmarks in current stack"
	-- 	)
	-- 	set(base_config.search_stacks, telescope.extensions.spelunk.stacks, "[spelunk.nvim] Fuzzy find stacks")
	-- end)

	-- Load saved bookmarks, if enabled and available
	-- Otherwise, set defaults
	---@type PhysicalStack[] | nil
	local physical_stacks
	enable_persist = conf.enable_persist or cfg.get_default("enable_persist")
	if enable_persist then
		physical_stacks = persist.load()
	end
	if not physical_stacks then
		vim.notify("EAW no phys stacks, fallback")
		physical_stacks = default_stacks
	end
	markmgr.init(physical_stacks, {
		persist_enabled = enable_persist,
		persist_cb = M.persist,
	}, show_status_col)

	-- Configure the prefix to use for the lualine integration
	statusline_prefix = conf.statusline_prefix or cfg.get_default("statusline_prefix")

	local set = cfg.set_keymap
	set(base_config.toggle, M.toggle_window, "[spelunk.nvim] Toggle UI")
	set(base_config.add, M.add_bookmark, "[spelunk.nvim] Add bookmark")
	set(
		base_config.next_bookmark,
		':lua require("spelunk").select_and_goto_bookmark(1)<CR>',
		"[spelunk.nvim] Go to next bookmark"
	)
	set(
		base_config.prev_bookmark,
		':lua require("spelunk").select_and_goto_bookmark(-1)<CR>',
		"[spelunk.nvim] Go to previous bookmark"
	)

	-- Register telescope extension, only if telescope itself is loaded already
	local telescope_loaded, telescope = pcall(require, "telescope")
	if not telescope_loaded or not telescope then
		return
	end
	telescope.load_extension("spelunk")
	set(base_config.search_bookmarks, telescope.extensions.spelunk.marks, "[spelunk.nvim] Fuzzy find bookmarks")
	set(
		base_config.search_current_bookmarks,
		telescope.extensions.spelunk.current_marks,
		"[spelunk.nvim] Fuzzy find bookmarks in current stack"
	)
	set(base_config.search_stacks, telescope.extensions.spelunk.stacks, "[spelunk.nvim] Fuzzy find stacks")
end

return M

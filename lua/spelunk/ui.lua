---@class CreateWinOpts
---@field title string
---@field line integer
---@field col integer
---@field minwidth integer
---@field minheight integer

---@class UpdateWinOpts
---@field cursor_index integer
---@field title string
---@field lines string[]
---@field bookmark PhysicalBookmark | nil
---@field max_stack_size integer

local layout = require("spelunk.layout")

local M = {}

---@type integer
local window_id = -1
---@type integer
local preview_window_id = -1
---@type integer
local help_window_id = -1

---@return boolean
M.is_open = function()
	return window_id ~= -1 or preview_window_id ~= -1 or help_window_id ~= -1
end

---@type table
local base_config
---@type table
local window_config
---@type string
local cursor_character

local focus_cb
local unfocus_cb


---@type integer | nil
M.previous_win_id = nil

---@param id integer
local window_ready = function(id)
	return id and id ~= -1 and vim.api.nvim_win_is_valid(id)
end

---@param win_id integer
---@param cleanup function
local persist_focus = function(win_id, cleanup)
	local bufnr = vim.api.nvim_win_get_buf(win_id)
	local group_name = string.format("SpelunkPersistFocus_%d", bufnr)

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
		vim.api.nvim_create_autocmd("WinEnter", {
			group = group_name,
			callback = cb,
			desc = "[spelunk.nvim] Hold focus",
		})
	end

	local unfocus = function()
		vim.api.nvim_del_augroup_by_name(group_name)
	end

	focus()

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win_id),
		callback = cleanup,
		desc = "[spelunk.nvim] Cleanup window exit",
	})

	return focus, unfocus
end

---@param filename string
---@param start_line integer
---@param end_line integer
---@return string[]
local read_lines = function(filename, start_line, end_line)
	local ok, lines = pcall(vim.fn.readfile, filename)
	if not ok then
		return { "[spelunk.nvim] Could not read file: " .. filename }
	end

	start_line = math.max(1, start_line)
	end_line = math.min(end_line, #lines)
	if end_line < start_line then
		return { "[spelunk.nvim] End line must be greater than or equal to start line" }
	end

	local result = {}
	for i = start_line, end_line do
		table.insert(result, lines[i])
	end
	return result
end

---@param base_cfg table
---@param window_cfg table
---@param cursor_char string
M.setup = function(base_cfg, window_cfg, cursor_char)
	base_config = base_cfg
	window_config = window_cfg
	if type(cursor_char) ~= "string" or string.len(cursor_char) ~= 1 then
		vim.notify("[spelunk.nvim] Passed invalid cursor character, falling back to default")
		cursor_char = ">"
	end
	cursor_character = cursor_char
end

---@param opts CreateWinOpts
local function create_window(opts)
  local bufnr = vim.api.nvim_create_buf(false, true)

  local border_chars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  local border = {
    { border_chars[5], "FloatBorder" }, -- top-left
    { border_chars[1], "FloatBorder" }, -- top
    { border_chars[6], "FloatBorder" }, -- top-right
    { border_chars[2], "FloatBorder" }, -- right
    { border_chars[7], "FloatBorder" }, -- bottom-right
    { border_chars[3], "FloatBorder" }, -- bottom
    { border_chars[8], "FloatBorder" }, -- bottom-left
    { border_chars[4], "FloatBorder" }, -- left
  }

  -- Window options for nvim_open_win
  local win_opts = {
    style = "minimal",
    relative = "editor",
    row = opts.line,
    col = opts.col,
    width = opts.minwidth,
    height = opts.minheight,
    border = border,
    title = opts.title,
    title_pos = "center",
  }

  local win_id = vim.api.nvim_open_win(bufnr, true, win_opts)

  vim.api.nvim_set_option_value("wrap", false, { win = win_id })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  return bufnr, win_id
end

M.show_help = function()
	if not layout.has_help_dimensions() then
		return
	end

	unfocus_cb()

	local dims = layout.help_dimensions()
	local bufnr, win_id = create_window({
		title = "Help - exit with 'q'",
		col = dims.col,
		line = dims.line,
		minwidth = dims.base.width,
		minheight = dims.base.height,
	})

	---@param arg string | string[]
	local fmt = function(arg)
		if type(arg) == "string" then
			return arg
		elseif type(arg) == "table" then
			return table.concat(arg, ", ")
		else
			error("[spelunk.nvim] ui.show_help.fmt passed unsupported type: " .. type(arg))
		end
	end

	local content = {
		"Normal Mappings",
		"---------------",
		"Toggle UI               " .. fmt(base_config.toggle),
		"Add bookmark            " .. fmt(base_config.add),
		"Change line             " .. fmt(base_config.change_line),
		"Next bookmark           " .. fmt(base_config.next_bookmark),
		"Prev bookmark           " .. fmt(base_config.prev_bookmark),
		"Search bookmarks        " .. fmt(base_config.search_bookmarks),
		"Search curr stack marks " .. fmt(base_config.search_current_bookmarks),
		"Search stacks           " .. fmt(base_config.search_stacks),
		"",
		"Window Mappings",
		"---------------",
		"Cursor down             " .. fmt(window_config.cursor_down),
		"Cursor up               " .. fmt(window_config.cursor_up),
		"Bookmark down           " .. fmt(window_config.bookmark_down),
		"Bookmark up             " .. fmt(window_config.bookmark_up),
		"Go to bookmark          " .. fmt(window_config.goto_bookmark),
		"Go to bookmark, split   " .. fmt(window_config.goto_bookmark_hsplit),
		"Go to bookmark, vsplit  " .. fmt(window_config.goto_bookmark_vsplit),
		"Go to bookmark at index " .. "# of index",
		"Delete bookmark         " .. fmt(window_config.delete_bookmark),
		"Next stack              " .. fmt(window_config.next_stack),
		"Previous stack          " .. fmt(window_config.previous_stack),
		"New stack               " .. fmt(window_config.new_stack),
		"Delete stack            " .. fmt(window_config.delete_stack),
		"Edit stack              " .. fmt(window_config.edit_stack),
		"Close                   " .. fmt(window_config.close),
		"Help                    " .. fmt(window_config.help),
	}
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
	help_window_id = win_id
	vim.api.nvim_buf_set_keymap(
		bufnr,
		"n",
		"q",
		': lua require("spelunk").close_help()<CR>',
		{ noremap = true, silent = true }
	)

	local _, _ = persist_focus(win_id, function()
		vim.api.nvim_del_augroup_by_name(string.format("SpelunkPersistFocus_%d", bufnr))
		vim.api.nvim_win_close(help_window_id, true)
		help_window_id = -1
		focus_cb()
	end)
end

M.close_help = function()
	vim.api.nvim_win_close(help_window_id, true)
end

---@param max_stack_size integer
local create_windows = function(max_stack_size)
	M.previous_win_id = vim.api.nvim_get_current_win()
	local bufnr, win_id
	if layout.has_bookmark_dimensions() then
		local win_dims = layout.bookmark_dimensions()
		bufnr, win_id = create_window({
			title = "Bookmarks",
			col = win_dims.col,
			line = win_dims.line,
			minwidth = win_dims.base.width,
			minheight = win_dims.base.height,
		})
		window_id = win_id
	end

	if layout.has_preview_dimensions() then
		local prev_dims = layout.preview_dimensions()
		local _, prev_id = create_window({
			title = "Preview",
			col = prev_dims.col,
			line = prev_dims.line,
			minwidth = prev_dims.base.width,
			minheight = prev_dims.base.height,
		})
		preview_window_id = prev_id
	end

	if bufnr then
		-- Set up keymaps for navigation within the window
		local set = require("spelunk.config").set_buf_keymap(bufnr)
		set(window_config.cursor_down, ':lua require("spelunk").move_cursor(1)<CR>', "[spelunk.nvim] Move cursor down")
		set(window_config.cursor_up, ':lua require("spelunk").move_cursor(-1)<CR>', "[spelunk.nvim] Move cursor up")
		set(
			window_config.bookmark_down,
			':lua require("spelunk").move_bookmark(1)<CR>',
			"[spelunk.nvim] Move bookmark down"
		)
		set(
			window_config.bookmark_up,
			':lua require("spelunk").move_bookmark(-1)<CR>',
			"[spelunk.nvim] Move bookmark up"
		)
		set(
			window_config.goto_bookmark,
			':lua require("spelunk").goto_selected_bookmark()<CR>',
			"[spelunk.nvim] Go to selected bookmark"
		)
		set(
			window_config.goto_bookmark_hsplit,
			':lua require("spelunk").goto_selected_bookmark_horizontal_split()<CR>',
			"[spelunk.nvim] Go to selected bookmark, in new horizontal split"
		)
		set(
			window_config.goto_bookmark_vsplit,
			':lua require("spelunk").goto_selected_bookmark_vertical_split()<CR>',
			"[spelunk.nvim] Go to selected bookmark, in new vertical split"
		)
		set(
			window_config.delete_bookmark,
			':lua require("spelunk").delete_selected_bookmark()<CR>',
			"[spelunk.nvim] Delete selected bookmark"
		)
		set(window_config.next_stack, ':lua require("spelunk").next_stack()<CR>', "[spelunk.nvim] Go to next stack")
		set(
			window_config.previous_stack,
			':lua require("spelunk").prev_stack()<CR>',
			"[spelunk.nvim] Go to previous stack"
		)
		set(window_config.new_stack, ':lua require("spelunk").new_stack()<CR>', "[spelunk.nvim] Create new stack")
		set(
			window_config.delete_stack,
			':lua require("spelunk").delete_current_stack()<CR>',
			"[spelunk.nvim] Delete current stack"
		)
		set(
			window_config.edit_stack,
			':lua require("spelunk").edit_current_stack()<CR>',
			"[spelunk.nvim] Edit the name of the current stack"
		)
		set(window_config.close, ':lua require("spelunk").close_windows()<CR>', "[spelunk.nvim] Close UI")
		set(window_config.help, ':lua require("spelunk").show_help()<CR>', "[spelunk.nvim] Show help menu")

		for i = 1, max_stack_size do
			set(
				tostring(i),
				string.format(':lua require("spelunk").goto_bookmark_at_index(%d)<CR>', i),
				string.format("[spelunk.nvim] Go to bookmark at stack position %d", i)
			)
		end

		focus_cb, unfocus_cb = persist_focus(win_id, function()
			if window_ready(window_id) then
				vim.api.nvim_win_close(window_id, true)
			end
			window_id = -1
			-- Defer preview window cleanup, as running it concurrently to main window
			-- causes it to not fire
			vim.schedule(function()
				if window_ready(preview_window_id) then
					vim.api.nvim_win_close(preview_window_id, true)
				end
				preview_window_id = -1
			end)
		end)
	end
end

---@param opts UpdateWinOpts
local update_preview = function(opts)
	if not window_ready(preview_window_id) or not opts.bookmark then
		return
	end
	local prev_dims = layout.preview_dimensions()
	local bufnr = vim.api.nvim_win_get_buf(preview_window_id)
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	local startline = math.max(1, math.ceil(opts.bookmark.line - (prev_dims.base.height / 2)))
	local lines = read_lines(opts.bookmark.file, startline, startline + prev_dims.base.height)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

	local ft = vim.filetype.match({ filename = opts.bookmark.file })
	if ft then
		vim.bo[bufnr].filetype = ft
	end

	vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
	---@diagnostic disable-next-line
	vim.api.nvim_buf_add_highlight(bufnr, -1, "Search", opts.bookmark.line - startline, 0, -1)
end

---@param opts UpdateWinOpts
M.update_window = function(opts)
	if not window_ready(window_id) then
		return
	end

	local bufnr = vim.api.nvim_win_get_buf(window_id)
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	local content_lines = {}
	for idx, line in ipairs(opts.lines) do
		local prefix = idx == opts.cursor_index and cursor_character or " "
		table.insert(content_lines, string.format("%s%2d %s", prefix, idx, line))
	end
	local content = { "Current stack: " .. opts.title, unpack(content_lines) }
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

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
M.toggle_window = function(opts)
	if window_ready(window_id) then
		M.close_windows()
	else
		create_windows(opts.max_stack_size)
		M.update_window(opts)
		vim.api.nvim_set_current_win(window_id)
	end
end

M.close_windows = function()
	if window_ready(window_id) then
		vim.api.nvim_win_close(window_id, true)
		vim.api.nvim_set_current_win(M.previous_win_id)
	end
end

return M

local status_ok, fzf = pcall(require, "fzf-lua")
if not status_ok or not fzf then
	vim.notify("[spelunk.nvim] fzf-lua is not installed, cannot be used for searching", vim.log.levels.ERROR)
	return false
end

local M = {}

---@param selected string[]
---@return string | nil
local get_selection = function(selected)
	-- Get the selected string
	if not selected or not #selected == 1 then
		vim.notify(
			"[spelunk.nvim] Received unexpected selection from fzf-lua: " .. vim.inspect(selected),
			vim.log.levels.WARN
		)
		return nil
	end
	return selected[1]
end

---@param opts SearchMarksOpts
M.search_marks = function(opts)
	---@type FullBookmarkWithText[]
	local bookmarks = {}
	---@type string[]
	local lines = {}
	for _, bookmark in ipairs(opts.data) do
		local search_text = string.format("%s.%s", bookmark.stack, opts.display_fn(bookmark))
		---@type FullBookmarkWithText
		local b = vim.tbl_extend("force", bookmark, {
			text = search_text,
		})
		table.insert(bookmarks, b)
		table.insert(lines, search_text)
	end

	---@param selected string[]
	local action = function(selected)
		-- Get the selected string
		local selection = get_selection(selected)
		if not selection then
			return
		end
		-- Find the bookmark from the string
		---@type FullBookmarkWithText | nil
		local found
		for _, bookmark in ipairs(bookmarks) do
			if bookmark.text == selection then
				found = bookmark
			end
		end
		if not found then
			vim.notify("[spelunk.nvim] Failed to find bookmark from fzf-lua selection", vim.log.levels.WARN)
			return
		end
		-- Go to selection
		opts.select_fn(found.file, found.line, found.col)
	end

	fzf.fzf_exec(lines, {
		prompt = string.format("%s> ", opts.prompt),
		actions = {
			["default"] = action,
		},
	})
end

---@param opts SearchStacksOpts
M.search_stacks = function(opts)
	---@type string[]
	local names = {}
	for _, stack in ipairs(opts.data) do
		table.insert(names, stack.name)
	end

	---@param selected string[]
	local action = function(selected)
		-- Get the selected string
		local selection = get_selection(selected)
		if not selection then
			return
		end
		-- Find the bookmark from the string
		---@type MarkStack | nil
		local found
		for _, stack in ipairs(opts.data) do
			if stack.name == selection then
				found = stack
			end
		end
		if not found then
			vim.notify("[spelunk.nvim] Failed to find stacks from fzf-lua selection", vim.log.levels.WARN)
			return
		end
		-- Go to selection
		opts.select_fn(found.name)
	end

	fzf.fzf_exec(names, {
		prompt = string.format("%s> ", opts.prompt),
		actions = {
			["default"] = action,
		},
	})
end

return M

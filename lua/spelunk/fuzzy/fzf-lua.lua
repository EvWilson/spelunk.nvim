local status_ok, fzf = pcall(require, "fzf-lua")
if not status_ok or not fzf then
	vim.notify("[spelunk.nvim] fzf-lua is not installed, cannot be used for searching", vim.log.levels.ERROR)
	return false
end

local util = require("spelunk.fuzzy.util")

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

local builtin = require("fzf-lua.previewer.builtin")

-- Inherit from the "buffer_or_file" previewer
local MarkPreviewer = builtin.buffer_or_file:extend()

function MarkPreviewer:new(o, opts, fzf_win)
	MarkPreviewer.super.new(self, o, opts, fzf_win)
	setmetatable(self, MarkPreviewer)
	return self
end

function MarkPreviewer:parse_entry(entry_str)
	-- Assume an arbitrary entry in the format of 'file:line'
	local path, line = entry_str:match("([^:]+):?(.*)")
	return {
		path = path,
		line = tonumber(line) or 1,
		col = 1,
	}
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

local StackPreviewer = builtin.base:extend()

function StackPreviewer:new(o, opts, fzf_win)
	StackPreviewer.super.new(self, o, opts, fzf_win)
	setmetatable(self, StackPreviewer)
	self.stack_map = opts.stack_map
	self.display_fn = opts.display_fn
	return self
end

function StackPreviewer:populate_preview_buf(entry_str)
	local tmpbuf = self:get_tmp_buffer()
	local lines = util.get_stack_lines(self.stack_map[entry_str], self.display_fn)
	vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, lines)
	self:set_preview_buf(tmpbuf)
	self.win:update_preview_scrollbar()
end

function StackPreviewer:gen_winopts()
	local new_winopts = {
		cursorline = false,
	}
	return vim.tbl_extend("force", self.winopts, new_winopts)
end

---@param opts SearchStacksOpts
M.search_stacks = function(opts)
	---@type string[]
	local names = {}
	---@type table<string, MarkStack>
	local name_to_stack = {}
	for _, stack in ipairs(opts.data) do
		table.insert(names, stack.name)
		name_to_stack[stack.name] = stack
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
			vim.notify("[spelunk.nvim] Failed to find stack from fzf-lua selection", vim.log.levels.WARN)
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
		previewer = StackPreviewer,
		stack_map = name_to_stack,
		display_fn = opts.display_fn,
	})
end

return M

local status_ok, snacks = pcall(require, "snacks")
if not status_ok or not snacks then
	vim.notify("[spelunk.nvim] snacks.nvim is not installed, cannot be used for searching", vim.log.levels.ERROR)
	return false
end

local M = {}

---@class FullBookmarkWithText : FullBookmark
---@field text string

---@param opts SearchMarksOpts
M.search_marks = function(opts)
	-- Add 'text' field to each item for searching
	---@type FullBookmarkWithText[]
	local items = {}
	for _, mark in ipairs(opts.data) do
		---@type FullBookmarkWithText
		local item = vim.tbl_extend("force", mark, {
			text = string.format("%s.%s", mark.stack, opts.display_fn(mark)),
		})
		table.insert(items, item)
	end

	snacks
		.picker({
			title = opts.prompt,
			items = items,
			---@param item FullBookmarkWithText
			format = function(item)
				-- return a table of fragments - { text, highlight_group }
				return {
					{ item.text, "SnacksPickerLabel" },
				}
			end,
			---@param picker any
			---@param item FullBookmarkWithText
			confirm = function(picker, item)
				picker:close()
				opts.select_fn(item.file, item.line, item.col)
			end,
		})
		:find()
end

---@class MarkStackWithText : MarkStack
---@field text string

---@param stack MarkStackWithText
---@param display_fn fun(mark: Mark): string
---@return string[]
local get_stack_lines = function(stack, display_fn)
	---@type string[]
	local lines = {}
	for _, mark in ipairs(stack.marks) do
		table.insert(lines, display_fn(mark))
	end
	return lines
end

---@param opts SpelunkSearchStacksOpts
M.search_stacks = function(opts)
	-- Add 'text' field to each item for searching
	---@type MarkStackWithText[]
	local items = {}
	for _, stack in ipairs(opts.data) do
		---@type MarkStackWithText
		local item = vim.tbl_extend("force", stack, {
			text = stack.name,
		})
		table.insert(items, item)
	end

	snacks
		.picker({
			title = opts.prompt,
			items = items,
			---@param item MarkStackWithText
			format = function(item)
				-- return a table of fragments - { text, highlight_group }
				return {
					{ item.text, "SnacksPickerLabel" },
				}
			end,
			preview = function(ctx)
				ctx.preview:set_lines(get_stack_lines(ctx.item, opts.display_fn))
			end,
			---@param picker any
			---@param item MarkStackWithText
			confirm = function(picker, item)
				picker:close()
				opts.select_fn(item.name)
			end,
		})
		:find()
end

return M

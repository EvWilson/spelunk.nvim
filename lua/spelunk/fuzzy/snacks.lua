local status_ok, snacks = pcall(require, "snacks")
if not status_ok or not snacks then
	vim.notify("[spelunk.nvim] snacks.nvim is not installed, cannot be used for searching", vim.log.levels.ERROR)
	return false
end

local util = require("spelunk.fuzzy.util")

local M = {}

---@class FullBookmarkWithText : FullBookmark
---@field text string

---@param opts SearchMarksOpts
M.search_marks = function(opts)
	-- Add 'text' field to each item for searching
	---@type FullBookmarkWithText[]
	local items = util.add_text(opts.data)

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

---@param opts SearchStacksOpts
M.search_stacks = function(opts)
	-- Add 'text' field to each item for searching
	---@type MarkStackWithText[]
	local items = util.add_text(opts.data)

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
				ctx.preview:set_lines(util.get_stack_lines(ctx.item, opts.display_fn))
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

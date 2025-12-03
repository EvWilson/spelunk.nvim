local M = {}

---@param opts SearchMarksOpts
M.search_marks = function(opts)
	vim.ui.select(
		opts.data,
		{
			prompt = opts.prompt,
			---@param item FullBookmark
			---@return string
			format_item = function(item)
				return string.format("%s.%s", item.stack, opts.display_fn(item))
			end,
		},
		---@param item FullBookmark | nil
		function(item)
			if not item then
				return
			end
			opts.select_fn(item.file, item.line, item.col)
		end
	)
end

---@param opts SearchStacksOpts
M.search_stacks = function(opts)
	vim.ui.select(
		opts.data,
		{
			prompt = opts.prompt,
			---@param item MarkStack
			---@return string
			format_item = function(item)
				return item.name
			end,
		},
		---@param item MarkStack | nil
		function(item)
			if not item then
				return
			end
			opts.select_fn(item.name)
		end
	)
end

return M

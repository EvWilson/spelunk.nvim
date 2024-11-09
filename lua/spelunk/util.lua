local M = {}

M.filename_formatter = function(abspath)
	return vim.fn.fnamemodify(abspath, ':~:.')
end

---@param fb FullBookmark
---@return string
function M.full_bookmark_to_string(fb)
	return string.format('%s.%s:%d', fb.stack, M.filename_formatter(fb.file), fb.line)
end

return M

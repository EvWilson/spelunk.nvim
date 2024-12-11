local M = {}

M.filename_formatter = function(abspath)
	return vim.fn.fnamemodify(abspath, ':~:.')
end

---@param fb FullBookmark
---@return string
M.full_bookmark_to_string = function(fb)
	return string.format('%s.%s:%d', fb.stack, M.filename_formatter(fb.file), fb.line)
end

---@param tbl table | nil
---@return integer
M.tbllen = function(tbl)
	if tbl == nil then
		return 0
	end
	local count = 0
	for _ in pairs(tbl) do count = count + 1 end
	return count
end

return M

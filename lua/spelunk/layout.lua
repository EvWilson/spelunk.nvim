local M = {}

---@type 'vertical' | 'horizontal'
local orientation

---@param o 'vertical' | 'horizontal'
function M.setup(o)
	orientation = o
end

---@return BaseDimensions
function M.base_dimensions()
	local width_portion = math.floor(vim.o.columns / 20)
	return {
		col_width = width_portion,
		standard_width = math.floor(width_portion * 8),
		standard_height = math.floor(vim.o.lines * 0.7),
	}
end

---@return WindowCoords
function M.bookmark_dimensions()
	local dims = M.base_dimensions()
	return {
		base = dims,
		line = math.floor(vim.o.lines / 2) - math.floor(dims.standard_height / 2),
		col = dims.col_width
	}
end

---@return WindowCoords
function M.preview_dimensions()
	local dims = M.base_dimensions()
	return {
		base = dims,
		line = math.floor(vim.o.lines / 2) - math.floor(dims.standard_height / 2),
		col = dims.col_width * 11,
	}
end

---@return WindowCoords
function M.help_dimensions()
	local dims = M.base_dimensions()
	return {
		base = dims,
		line = math.floor(vim.o.lines / 2) - math.floor(dims.standard_height / 2) - 2,
		col = dims.col_width * 6,
	}
end

return M

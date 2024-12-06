local M = {}

---@type 'vertical' | 'horizontal' | LayoutProvider
local orientation

---@return integer
local function width_portion()
	return math.floor(vim.o.columns / 20)
end

---@return integer
local function height_portion()
	return math.floor(vim.o.lines / 12)
end

---@return boolean
local function vert()
	return orientation == 'vertical'
end

---@return BaseDimensions
function M.base_dimensions()
	if vert() then
		return {
			width = width_portion() * 8,
			height = height_portion() * 9,
		}
	else
		return {
			width = width_portion() * 16,
			height = height_portion() * 5,
		}
	end
end

---@return WindowCoords
local bookmark_dimension_func = function()
	local dims = M.base_dimensions()
	if vert() then
		return {
			base = dims,
			line = math.floor(vim.o.lines / 2) - math.floor(dims.height / 2),
			col = width_portion(),
		}
	else
		return {
			base = dims,
			line = height_portion(),
			col = width_portion() * 2,
		}
	end
end

---@return WindowCoords
local preview_dimension_func = function()
	local dims = M.base_dimensions()
	if vert() then
		return {
			base = dims,
			line = math.floor(vim.o.lines / 2) - math.floor(dims.height / 2),
			col = width_portion() * 11,
		}
	else
		return {
			base = dims,
			line = height_portion() * 7,
			col = width_portion() * 2,
		}
	end
end

---@return WindowCoords
local help_dimension_func = function()
	local dims = M.base_dimensions()
	if vert() then
		return {
			base = dims,
			line = math.floor(vim.o.lines / 2) - math.floor(dims.height / 2) - 2,
			col = width_portion() * 6,
		}
	else
		return {
			base = dims,
			line = height_portion() * 3,
			col = width_portion() * 2,
		}
	end
end

---@param o 'vertical' | 'horizontal' | LayoutProvider
function M.setup(o)
	if o ~= 'vertical' and o ~= 'horizontal' and type(o) ~= 'table' then
		error('[spelunk.nvim] Layout engine passed an unsupported orientation: ' .. vim.inspect(o))
	end
	if type(o) == 'string' then
		M.bookmark_dimensions = bookmark_dimension_func
		M.preview_dimensions = preview_dimension_func
		M.help_dimensions = help_dimension_func
	else
		M.bookmark_dimensions = o.bookmark_dimensions
		M.preview_dimensions = o.preview_dimensions
		M.help_dimensions = o.help_dimensions
	end
	orientation = o
end

return M

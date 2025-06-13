---@class BaseDimensions
---@field width integer
---@field height integer

---@class WindowCoords
---@field base BaseDimensions
---@field line integer
---@field col integer

---@class LayoutProvider
---@field bookmark_dimensions nil | fun(): WindowCoords
---@field preview_dimensions nil | fun(): WindowCoords
---@field help_dimensions nil | fun(): WindowCoords

local M = {}

---@type 'vertical' | 'horizontal' | LayoutProvider
local orientation

---@return integer
local width_portion = function()
	return math.floor(vim.o.columns / 20)
end

---@return integer
local height_portion = function()
	return math.floor(vim.o.lines / 12)
end

---@return boolean
local vert = function()
	return orientation == "vertical"
end

---@return BaseDimensions
M.base_dimensions = function()
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

---@return boolean
M.has_bookmark_dimensions = function()
	return M.bookmark_dimensions ~= nil
end

---@return boolean
M.has_preview_dimensions = function()
	return M.preview_dimensions ~= nil
end

---@return boolean
M.has_help_dimensions = function()
	return M.help_dimensions ~= nil
end

---@param o "vertical" | "horizontal" | LayoutProvider
M.setup = function(o)
	if o ~= "vertical" and o ~= "horizontal" and type(o) ~= "table" then
		error("[spelunk.nvim] Layout engine passed an unsupported orientation: " .. vim.inspect(o))
	end
	if type(o) == "string" then
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

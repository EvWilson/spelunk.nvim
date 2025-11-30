local M = {}

---@class MarkStackWithText : MarkStack
---@field text string

---@param stack MarkStackWithText
---@param display_fn fun(mark: Mark): string
---@return string[]
M.get_stack_lines = function(stack, display_fn)
	---@type string[]
	local lines = {}
	for _, mark in ipairs(stack.marks) do
		table.insert(lines, display_fn(mark))
	end
	return lines
end

return M

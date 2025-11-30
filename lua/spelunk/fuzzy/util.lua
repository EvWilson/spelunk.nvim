local M = {}

---@param stacks MarkStack[]
---@return MarkStackWithText[]
M.add_text = function(stacks)
	local items = {}
	for _, stack in ipairs(stacks) do
		---@type MarkStackWithText
		local item = vim.tbl_extend("force", stack, {
			text = stack.name,
		})
		table.insert(items, item)
	end
	return items
end

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

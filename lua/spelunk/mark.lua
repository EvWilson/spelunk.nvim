local M = {}

---@type integer
local ns_id = vim.api.nvim_create_namespace('spelunk')

---@param virt VirtualBookmark
---@return PhysicalBookmark
M.virt_to_physical = function(virt)
	local mark = vim.api.nvim_buf_get_extmark_by_id(virt.bufnr, ns_id, virt.mark_id, {})
	return {
		file = vim.api.nvim_buf_get_name(virt.bufnr),
		line = mark[1],
		col = mark[2],
	}
end

---@param virtstacks VirtualStack[]
---@return PhysicalStack[]
M.virt_to_physical_stack = function(virtstacks)
	local ret = {}
	for i, stack in ipairs(virtstacks) do
		local physstack = { name = virtstacks[i].name, bookmarks = {} }
		for _, mark in pairs(stack.bookmarks) do
			table.insert(physstack.bookmarks, M.virt_to_physical(mark))
		end
		table.insert(ret, physstack)
	end
	return ret
end

---@return VirtualBookmark
M.set_mark_current_pos = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local line = vim.fn.line('.')
	local col = vim.fn.col('.')
	local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, col, {
		strict = false, -- Allow the mark to move with edits
		right_gravity = true, -- Mark stays at end of inserted text
	})
	return {
		bufnr = bufnr,
		mark_id = mark_id,
	}
end

---@param mark PhysicalBookmark
---@return VirtualBookmark
local set_mark = function(mark)
	local bufnr = vim.fn.bufadd(mark.file)
	vim.fn.bufload(bufnr)
	local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.line, mark.col, {
		strict = false, -- Allow the mark to move with edits
		right_gravity = true, -- Mark stays at end of inserted text
	})
	return {
		bufnr = bufnr,
		mark_id = mark_id,
	}
end

---@param stacks PhysicalStack[]
---@return VirtualStack[]
M.setup = function(stacks)
	---@type VirtualStack[]
	local vstack = {}
	for idx, stack in ipairs(stacks) do
		table.insert(vstack, { name = stacks[idx].name, bookmarks = {} })
		for _, mark in pairs(stack.bookmarks) do
			local virtmark = set_mark(mark)
			table.insert(vstack[idx].bookmarks, virtmark)
		end
	end
	return vstack
end

return M

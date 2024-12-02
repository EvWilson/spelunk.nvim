local M = {}

---@type string
local ns_name = 'spelunk'
---@type integer
local ns_id = vim.api.nvim_create_namespace(ns_name)

---@param filepath string
---@return integer
local function get_or_create_buf(filepath)
	local bufnr = vim.fn.bufnr(filepath)
	if bufnr == -1 then
		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(bufnr, filepath)
	end

	local success = pcall(function()
		vim.fn.readfile(filepath)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(filepath))
	end)

	if not success then
		vim.api.nvim_buf_delete(bufnr, { force = true })
		return -1
	end
	return bufnr
end

---@param mark PhysicalBookmark
---@return VirtualBookmark
local function set_virtmark(mark)
	local bufnr = get_or_create_buf(mark.file)
	if bufnr == -1 then
		error("[spelunk.nvim] set_extmark called for file without buffer")
	end
	local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.line, 0, {
		strict = false, -- Allow the mark to move with edits
		right_gravity = true, -- Mark stays at end of inserted text
	})
	return {
		bufnr = bufnr,
		mark_id = mark_id,
	}
end

---@param virt VirtualBookmark
---@return PhysicalBookmark
function M.virt_to_physical(virt)
	local mark = vim.api.nvim_buf_get_extmark_by_id(virt.bufnr, ns_id, virt.mark_id, {})
	return {
		file = vim.api.nvim_buf_get_name(virt.bufnr),
		line = mark[1],
		col = mark[2],
	}
end

---@param stacks PhysicalStack[]
local function setup_extmarks(stacks)
	for _, stack in pairs(stacks) do
		for _, mark in pairs(stack.bookmarks) do
			local virtmark = set_virtmark(mark)
		end
	end
end

---@param stacks PhysicalStack[]
function M.setup(stacks)
	setup_extmarks(stacks)
end

return M

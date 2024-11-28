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
		vim.api.nvim_buf_set_var(bufnr, 'buftype', 'nofile')
		vim.fn.readfile(filepath)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(filepath))
	end)

	if not success then
		vim.api.nvim_buf_delete(bufnr, { force = true })
		return -1
	end
	return bufnr
end


---@param mark Bookmark
---@return integer
local function set_extmark(mark)
	local bufnr = get_or_create_buf(mark.file)
	if bufnr == -1 then
		error("[spelunk.nvim] set_extmark called for file without buffer")
	end
	local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.line, 0, {
		strict = false, -- Allow the mark to move with edits
		right_gravity = true, -- Mark stays at end of inserted text
	})
	return mark_id
end

---@param stacks BookmarkStack[]
local function setup_extmarks(stacks)
	for _, stack in pairs(stacks) do
		for _, mark in pairs(stack.bookmarks) do
			local mark_id = set_extmark(mark)
		end
	end
end

---@class AutoCmdArgs
---@field buf integer

---@param args AutoCmdArgs
local function on_change(args)
	local bufnr = args.buf
	local ems = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})
	print('code changed!')
end

---@param stacks BookmarkStack
function M.setup(stacks)
	setup_extmarks(stacks)

	-- Set callback to update marks on code changes
	local augroup = vim.api.nvim_create_augroup('SpelunkCodeChangeCallback', { clear = true })
	vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
		group = augroup,
		pattern = '*',
		callback = on_change,
		desc = '[spelunk.nvim] Trigger callback on code changes'
	})
end

-- function M.set_mark_at_current_pos()
-- 	local bufnr = vim.api.nvim_get_current_buf()
-- 	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
-- 	row = row - 1
--
-- 	local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
-- 		strict = false, -- Allow the mark to move with edits
-- 		right_gravity = true, -- Mark stays at end of inserted text
-- 	})
--
-- 	return mark_id
-- end
--
-- function M.set_mark(bufnr, ns_id, row, col)
-- 	local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
-- 		strict = false, -- Allow the mark to move with edits
-- 		right_gravity = true, -- Mark stays at end of inserted text
-- 	})
--
-- 	return mark_id
-- end
--
-- function M.get_mark_position(mark_id)
-- 	local pos = vim.api.nvim_buf_get_extmark_by_id(
-- 		mark.buffer,
-- 		ns_id,
-- 		mark_id,
-- 		{ details = true }
-- 	)
--
--
-- 	if not pos or #pos == 0 then
-- 		return nil, "Mark position not found"
-- 	end
--
-- 	-- Convert to 1-based line number for consistency with Neovim API
-- 	return {
-- 		line = pos[1] + 1,
-- 		col = pos[2],
-- 		buffer = mark.buffer
-- 	}
-- end

return M

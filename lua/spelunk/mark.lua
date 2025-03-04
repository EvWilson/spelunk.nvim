local M = {}

---@type integer
local ns_id = vim.api.nvim_create_namespace('spelunk')

local show_status_col

---@param extmark vim.api.keyset.get_extmark_item
---@return boolean
local extmark_ok = function(extmark)
	return extmark[1] ~= nil and extmark[2] ~= nil
end

---@param mark PhysicalBookmark
---@param idx integer
---@return VirtualBookmark
local set_mark = function(mark, idx)
	local bufnr = vim.fn.bufadd(mark.file)
	local old_swapfile = vim.o.swapfile
	vim.o.swapfile = false
	vim.fn.bufload(bufnr)
	vim.o.swapfile = old_swapfile
	local opts = {
		strict = false,
		right_gravity = true,
	}
	if show_status_col then
		opts.sign_text = tostring(idx)
	end
	local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.line - 1, mark.col - 1, opts)

	return {
		file = mark.file,
		line = mark.line,
		col = mark.col,
		bufnr = bufnr,
		mark_id = mark_id,
		meta = mark.meta,
	}
end

---@param virt VirtualBookmark
---@return PhysicalBookmark
M.virt_to_physical = function(virt)
	---@param vmark VirtualBookmark
	---@return boolean, vim.api.keyset.get_extmark_item
	local get_mark = function(vmark)
		return pcall(vim.api.nvim_buf_get_extmark_by_id, vmark.bufnr, ns_id, vmark.mark_id, {})
	end
	local ok, mark = get_mark(virt)
	if not ok or not extmark_ok(mark) then
		virt = set_mark({
			file = virt.file,
			line = virt.line,
			col = virt.col,
			meta = virt.meta,
		}, 0)
		_, mark = get_mark(virt)
	end
	return {
		file = vim.api.nvim_buf_get_name(virt.bufnr),
		line = mark[1] + 1,
		col = mark[2] + 1,
		meta = virt.meta,
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

---@param idx integer
---@return VirtualBookmark
M.set_mark_current_pos = function(idx)
	return set_mark({
		file = vim.api.nvim_buf_get_name(0),
		line = vim.fn.line('.'),
		col = vim.fn.col('.'),
		meta = {},
	}, idx)
end

---@param virt VirtualBookmark
---@return boolean
M.delete_mark = function(virt)
	return vim.api.nvim_buf_del_extmark(virt.bufnr, ns_id, virt.mark_id)
end

---@param virtstack VirtualStack
M.delete_stack = function(virtstack)
	for _, mark in pairs(virtstack.bookmarks) do
		M.delete_mark(mark)
	end
end

---@param virtstack VirtualStack
M.update_indices = function(virtstack)
	for idx, vmark in ipairs(virtstack.bookmarks) do
		local mark = M.virt_to_physical(vmark)
		-- Watch this option set for drift with the main setter
		-- Need this to add the edit ID
		local opts = {
			id = vmark.mark_id,
			strict = false,
			right_gravity = true,
			sign_text = tostring(idx),
		}
		vim.api.nvim_buf_set_extmark(vmark.bufnr, ns_id, mark.line - 1, mark.col - 1, opts)
	end
end

---@param stacks PhysicalStack[]
---@param show_status boolean
---@param enable_persist boolean
---@param persist_cb fun()
---@param get_stack_cb fun(): VirtualStack[]
---@return VirtualStack[]
M.setup = function(stacks, show_status, enable_persist, persist_cb, get_stack_cb)
	show_status_col = show_status

	if #stacks == 0 then
		return {}
	end

	---@type VirtualStack[]
	local vstack = {}
	for idx, stack in ipairs(stacks) do
		table.insert(vstack, { name = stacks[idx].name, bookmarks = {} })
		for i, mark in ipairs(stack.bookmarks) do
			local virtmark = set_mark(mark, i)
			table.insert(vstack[idx].bookmarks, virtmark)
		end
	end

	-- Create a callback to persist changes to mark locations on file updates
	if enable_persist then
		local persist_augroup = vim.api.nvim_create_augroup('SpelunkPersistCallback', { clear = true })
		vim.api.nvim_create_autocmd('BufWritePost', {
			group = persist_augroup,
			pattern = '*',
			callback = function(ctx)
				local bufnr = ctx.buf
				if not bufnr then
					return
				end
				for _, stack in pairs(get_stack_cb()) do
					for _, mark in pairs(stack.bookmarks) do
						if bufnr == mark.bufnr then
							persist_cb()
							return
						end
					end
				end
			end,
			desc = '[spelunk.nvim] Persist mark updates on file change'
		})
	end

	return vstack
end

return M

-- Main mark types

---@class MarkStack
---@field name string
---@field marks Mark[]

---@alias MarkMeta table<string, any>

---@class Mark
---@field file string
---@field line integer
---@field col integer
---@field meta MarkMeta
---@field bufnr integer | nil
---@field extmark_id integer | nil

---@class PersistMarksArgs
---@field persist_enabled boolean
---@field persist_cb fun()

---@alias StringSet table<string, true>

-- Utility types

---@class PhysicalBookmark
---@field file string
---@field line integer
---@field col integer
---@field meta MarkMeta

---@class FullBookmark
---@field stack string
---@field file string
---@field line integer
---@field col integer
---@field meta MarkMeta

---@class PhysicalStack
---@field name string
---@field bookmarks PhysicalBookmark[]

local util = require("spelunk.util")

---@type MarkStack[]
local stacks

-- Specifically here to help determine whether to bootstrap extmarks on initial buf enter
---@type StringSet
local file_set

---@type boolean
local show_status_col

local M = {}

---@type integer
local ns_id = vim.api.nvim_create_namespace("spelunk")

---@return Mark
local new_mark = function()
	---@type Mark
	return {
		file = vim.api.nvim_buf_get_name(0),
		line = vim.fn.line("."),
		col = vim.fn.col("."),
		meta = {},
	}
end

-- Utility to standardize the setting of extmarks
---@param mark Mark
---@param bufnr integer
---@param idx_in_stack integer
---@return Mark
local set_extmark = function(mark, bufnr, idx_in_stack)
	local opts = {
		strict = false,
		right_gravity = true,
	}
	if show_status_col then
		opts.sign_text = tostring(idx_in_stack)
	end
	local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.line - 1, mark.col - 1, opts)
	mark.bufnr = bufnr
	mark.extmark_id = mark_id
	return mark
end

-- Update the sign column indices when updates are made to the stack
---@param stack_idx integer
M.update_indices = function(stack_idx)
	for mark_idx, mark in ipairs(stacks[stack_idx].marks) do
		if not mark.extmark_id then
			goto continue
		end
		-- Watch this option set for drift with the main setter
		-- Need this to add the edit ID
		local opts = {
			id = mark.extmark_id,
			strict = false,
			right_gravity = true,
			sign_text = tostring(mark_idx),
		}
		-- Discard in this instance, extmark_id and bufnr should remain unchanged
		local _ = vim.api.nvim_buf_set_extmark(mark.bufnr, ns_id, mark.line - 1, mark.col - 1, opts)
		::continue::
	end
end

-- Register autocmd to reapply extmarks when a relevant buffer is opened for the first time
local new_buf_cb = function()
	vim.api.nvim_create_autocmd("BufWinEnter", {
		pattern = "*",
		callback = function(ctx)
			if vim.b.spelunk_entry or not file_set[ctx.file] then
				return
			end
			vim.b.spelunk_entry = true
			for stack_idx, stack in ipairs(stacks) do
				for mark_idx, mark in ipairs(stack.marks) do
					if mark.file == ctx.file then
						stacks[stack_idx].marks[mark_idx] = set_extmark(mark, ctx.buf, mark_idx)
					end
				end
			end
		end,
		desc = "[spelunk.nvim] Reapply bookmark extmarks to opened buffers",
	})
end

-- Get (row, col) position of extmark
---@param bufnr integer
---@param id integer
---@return integer, integer
local get_extmark_pos = function(bufnr, id)
	local res = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_id, id, {})
	return res[1] + 1, res[2] + 1
end

---@param bufnr integer
local update_mark_locations = function(bufnr)
	if not bufnr then
		return
	end
	for _, stack in pairs(stacks) do
		for _, mark in pairs(stack.marks) do
			if mark.extmark_id and mark.bufnr == bufnr then
				local row, col = get_extmark_pos(bufnr, mark.extmark_id)
				mark.line = row
				mark.col = col
			end
		end
	end
end

---@param persist_args PersistMarksArgs
---@param bufnr integer
local persist_mark_updates = function(persist_args, bufnr)
	if not persist_args.persist_enabled then
		return
	end
	if not bufnr then
		return
	end
	for _, stack in pairs(stacks) do
		for _, mark in pairs(stack.marks) do
			if mark.bufnr == bufnr then
				persist_args.persist_cb()
				return
			end
		end
	end
end

-- Create a callback to update mark locations and persist on relevant edits
---@param args PersistMarksArgs
local register_and_persist_updates = function(args)
	if args.persist_enabled then
		local persist_augroup = vim.api.nvim_create_augroup("SpelunkPersistCallback", { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = persist_augroup,
			pattern = "*",
			callback = function(ctx)
				update_mark_locations(ctx.buf)
				persist_mark_updates(args, ctx.buf)
			end,
			desc = "[spelunk.nvim] Persist mark updates on file change",
		})
	end
end

---@param phys_stacks PhysicalStack[]
---@param persist_args PersistMarksArgs
---@param show_status boolean
M.init = function(phys_stacks, persist_args, show_status)
	show_status_col = show_status
	stacks = {}
	file_set = {}

	for _, stack in ipairs(phys_stacks) do
		---@type MarkStack
		local newstack = {
			name = stack.name,
			marks = {},
		}
		for _, mark in ipairs(stack.bookmarks) do
			file_set[mark.file] = true
			---@type Mark
			local newmark = util.copy_tbl(mark)
			table.insert(newstack.marks, newmark)
		end
		table.insert(stacks, newstack)
	end

	new_buf_cb()
	register_and_persist_updates(persist_args)
end

---@return integer
M.len_stacks = function()
	return #stacks
end

---@param stack_idx integer
---@return integer
M.len_marks = function(stack_idx)
	return #stacks[stack_idx].marks
end

---@return integer
M.max_stack_len = function()
	local max = 0
	for _, stack in ipairs(stacks) do
		local sz = #stack.marks
		if sz > max then
			max = sz
		end
	end
	return max
end

---@param stack_idx integer
---@param mark_idx integer
---@return boolean
M.valid_indices = function(stack_idx, mark_idx)
	local mark = stacks[stack_idx].marks[mark_idx]
	if mark then
		return true
	else
		return false
	end
end

---@param stack_idx integer
---@return string
M.get_stack_name = function(stack_idx)
	return stacks[stack_idx].name
end

---@param stack_idx integer
---@param stack_name string
M.set_stack_name = function(stack_idx, stack_name)
	stacks[stack_idx].name = stack_name
end

---@return string[]
M.stack_names = function()
	---@type string[]
	local stack_names = {}
	for _, stack in ipairs(stacks) do
		table.insert(stack_names, stack.name)
	end
	return stack_names
end

---@param stack_name string
---@return integer
M.stack_idx_for_name = function(stack_name)
	for idx, stack in ipairs(stacks) do
		if stack.name == stack_name then
			return idx
		end
	end
	return -1
end

---@param filename string
---@param current_stack_index integer
---@return integer
M.instances_of_file = function(filename, current_stack_index)
    local count = 0
    ---@type MarkStack
    local currstack = stacks[current_stack_index]
    for _, mark in ipairs(currstack.marks) do
        if mark.file == filename then
            count = count + 1
        end
    end
    return count
end

-- Moves mark at the given indices in the given direction, returning whether or not the move was performed.
---@param stack_idx integer
---@param mark_idx integer
---@param mark_delta 1 | -1
---@return boolean
M.move_mark_in_stack = function(stack_idx, mark_idx, mark_delta)
	-- No need to move if there's at most one mark
	if #stacks[stack_idx].marks < 2 then
		return false
	end
	-- Don't perform the move if moving to an invalid location
	local newidx = mark_idx + mark_delta
	if newidx < 1 or newidx > #stacks[stack_idx].marks then
		return false
	end
	local currmark = stacks[stack_idx].marks[mark_idx]
	local newmark = stacks[stack_idx].marks[newidx]
	stacks[stack_idx].marks[mark_idx] = newmark
	stacks[stack_idx].marks[newidx] = currmark
	return true
end

---@param stack_idx integer
---@param mark_idx integer
---@param mark_delta 1 | -1
---@return integer
M.move_mark_idx = function(stack_idx, mark_idx, mark_delta)
	local currmarks = stacks[stack_idx].marks
	local new_mark_idx = mark_idx + mark_delta
	if new_mark_idx < 1 then
		new_mark_idx = math.max(#currmarks, 1)
	elseif new_mark_idx > #currmarks then
		new_mark_idx = 1
	end
	return new_mark_idx
end

---@param stack_idx integer
M.add_mark_current_pos = function(stack_idx)
	local bufnr = vim.api.nvim_get_current_buf()
	local newmark = new_mark()
	newmark.bufnr = bufnr
	table.insert(stacks[stack_idx].marks, newmark)
	newmark = set_extmark(newmark, bufnr, #stacks[stack_idx].marks)
	vim.notify(
		string.format(
			"[spelunk.nvim] Bookmark added to stack '%s': %s:%d:%d",
			stacks[stack_idx].name,
			newmark.file,
			newmark.line,
			newmark.col
		)
	)
end

---@param stack_name string
---@return integer
M.add_stack = function(stack_name)
	---@type MarkStack
	local newstack = {
		name = stack_name,
		marks = {},
	}
	table.insert(stacks, newstack)
	return #stacks
end

---@param stack_idx integer
---@param mark_idx integer
---@return integer
M.delete_mark = function(stack_idx, mark_idx)
	---@type Mark
	local delmark = table.remove(stacks[stack_idx].marks, mark_idx)
	if delmark.extmark_id then
		local success = vim.api.nvim_buf_del_extmark(delmark.bufnr, ns_id, delmark.extmark_id)
		if not success then
			vim.notify(string.format("[spelunk.nvim] Error occurred deleting mark at index %d:%d", stack_idx, mark_idx))
		end
	end
	local len = M.len_marks(stack_idx)
	if mark_idx > len and len ~= 0 then
		mark_idx = len
	end
	return mark_idx
end

---@param stack_idx integer
M.delete_stack = function(stack_idx)
	if #stacks < 2 then
		vim.notify("[spelunk.nvim] Cannot delete a stack when you have less than two")
		return
	end
	local stack = table.remove(stacks, stack_idx)
	for mark_idx, delmark in ipairs(stack.marks) do
		if not delmark.extmark_id then
			goto continue
		end
		local success = vim.api.nvim_buf_del_extmark(delmark.bufnr, ns_id, delmark.extmark_id)
		if not success then
			vim.notify(
				string.format(
					"[spelunk.nvim] Error occurred deleting extmark for mark at index %d:%d",
					stack_idx,
					mark_idx
				)
			)
		end
		::continue::
	end
end

---@param stack_idx integer
---@param mark_idx integer
---@return PhysicalBookmark
M.physical_mark = function(stack_idx, mark_idx)
	local mark = stacks[stack_idx].marks[mark_idx]
	return {
		file = mark.file,
		line = mark.line,
		col = mark.col,
		meta = mark.meta,
	}
end

---@param stack_idx integer
---@return PhysicalStack
M.physical_stack = function(stack_idx)
	---@type MarkStack
	local currstack = stacks[stack_idx]
	---@type PhysicalStack
	local s = {
		name = currstack.name,
		bookmarks = {},
	}
	for idx, _ in ipairs(currstack.marks) do
		table.insert(s.bookmarks, M.physical_mark(stack_idx, idx))
	end
	return s
end

---@return PhysicalStack[]
M.physical_stacks = function()
	---@type PhysicalStack[]
	local s = {}
	for idx, _ in ipairs(stacks) do
		table.insert(s, M.physical_stack(idx))
	end
	return s
end

---@param stack_idx integer
---@param mark_idx integer
---@param field string
---@param val any
M.add_mark_meta = function(stack_idx, mark_idx, field, val)
	stacks[stack_idx].marks[mark_idx].meta[field] = val
end

---@param stack_idx integer
---@param mark_idx integer
---@param field string
---@return any | nil
M.get_mark_meta = function(stack_idx, mark_idx, field)
	return stacks[stack_idx].marks[mark_idx].meta[field]
end

---@return MarkStack[]
M.stacks = function()
	return stacks
end

return M

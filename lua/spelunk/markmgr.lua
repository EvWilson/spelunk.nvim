local util = require("spelunk.util")

---@type MarkStack[]
local stacks

---@type StringSet
local file_set

---@type boolean
local show_status_col

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
		extmark_id = nil,
	}
end

--- Utility to standardize the setting of extmarks
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

---@param stack_idx integer
M.update_indices = function(stack_idx)
	for idx, mark in ipairs(stacks[stack_idx]) do
		-- Watch this option set for drift with the main setter
		-- Need this to add the edit ID
		local opts = {
			id = mark.extmark_id,
			strict = false,
			right_gravity = true,
			sign_text = tostring(idx),
		}
		vim.api.nvim_buf_set_extmark(mark.bufnr, ns_id, mark.line - 1, mark.col - 1, opts)
	end
end

--- Register autocmd to reapply extmarks when a relevant buffer is opened for the first time
local new_buf_cb = function()
	vim.api.nvim_create_autocmd("BufNew", {
		callback = function(ctx)
			if file_set[ctx.file] then
				-- print("Matched new buf:", ctx.file)
				for istack, stack in ipairs(stacks) do
					for imark, mark in ipairs(stack.marks) do
						if mark.file == ctx.file then
							stacks[istack].marks[imark] = set_extmark(mark, ctx.buf, imark)
						end
					end
				end
			end
			-- print("new mgr:", vim.inspect(mgr))
		end,
		desc = "[spelunk.nvim] Reapply bookmark extmarks to newly opened buffers",
	})
end

--- Create a callback to persist changes to mark locations on file updates
---@param args PersistMarksArgs
local persist_mark_updates = function(args)
	if args.persist_enabled then
		local persist_augroup = vim.api.nvim_create_augroup("SpelunkPersistCallback", { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = persist_augroup,
			pattern = "*",
			callback = function(ctx)
				if not args.persist_enabled then
					return
				end
				local bufnr = ctx.buf
				if not bufnr then
					return
				end
				for _, stack in pairs(stacks) do
					for _, mark in pairs(stack.marks) do
						if mark.bufnr == ctx.buf then
							args.persist_cb()
							return
						end
					end
				end
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
	persist_mark_updates(persist_args)
end

---@return integer
M.len_stacks = function()
	return #stacks
end

---@param stack_idx integer
---@return integer
M.len_marks = function(stack_idx)
	return #stacks[stack_idx]
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
---@return integer
M.instances_of_file = function(filename)
	local count = 0
	for _, stack in ipairs(stacks) do
		for _, mark in ipairs(stack.marks) do
			if mark.file == filename then
				count = count + 1
			end
		end
	end
	return count
end

---@param stack_idx integer
---@param mark_idx integer
---@param mark_delta 1 | -1
M.move_mark_in_stack = function(stack_idx, mark_idx, mark_delta)
	-- No need to move if there's at most one mark
	if #stacks[stack_idx].marks < 2 then
		return
	end
	-- Don't perform the move if moving to an invalid location
	local newidx = mark_idx + mark_delta
	if newidx < 1 or newidx > #stacks[stack_idx].marks then
		return
	end
	local currmark = stacks[stack_idx].marks[mark_idx]
	local newmark = stacks[stack_idx].marks[newidx]
	stacks[stack_idx].marks[mark_idx] = newmark
	stacks[stack_idx].marks[newidx] = currmark
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
	vim.notify("EAW stack state after adding: " .. vim.inspect(stacks))
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
	local delmark = table.remove(stacks[stack_idx].marks, mark_idx)
	local success = vim.api.nvim_buf_del_extmark(delmark.bufnr, ns_id, delmark.mark_id)
	if not success then
		vim.notify(string.format("[spelunk.nvim] Error occurred deleting mark at index %d:%d", stack_idx, mark_idx))
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
	local stack = table.remove(stacks[stack_idx])
	for mark_idx, delmark in ipairs(stack.marks) do
		local success = vim.api.nvim_buf_del_extmark(delmark.bufnr, ns_id, delmark.mark_id)
		if not success then
			vim.notify(
				string.format(
					"[spelunk.nvim] Error occurred deleting extmark for mark at index %d:%d",
					stack_idx,
					mark_idx
				)
			)
		end
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

return M

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

local util = require("spelunk.util")

---@class MarkManager
---@field stacks MarkStack[]
---@field file_set StringSet
---@field mark_index MarkID

---@alias StringSet table<string, true>

---@class MarkStack
---@field name string
---@field marks Mark[]

---@alias MarkMeta table<string, any>

---@alias MarkID integer A handle to a mark managed within spelunk

---@class Mark
---@field file string
---@field line integer
---@field col integer
---@field meta MarkMeta
---@field bufnr integer | nil
---@field extmark_id integer | nil
---@field mark_id MarkID

---@class PersistMarksArgs
---@field persist_enabled boolean
---@field persist_cb fun()

local MarkManager = {}
MarkManager.__index = MarkManager

---@type integer
local ns_id = vim.api.nvim_create_namespace("spelunk")

--- Utility to standardize the setting of extmarks
---@param mark Mark
---@param bufnr integer
---@return Mark
---@param show_status_col boolean
local set_extmark = function(mark, bufnr, show_status_col, idx)
	local opts = {
		strict = false,
		right_gravity = true,
	}
	if show_status_col then
		opts.sign_text = tostring(idx)
	end
	local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.line - 1, mark.col - 1, opts)
	mark.bufnr = bufnr
	mark.extmark_id = mark_id
	return mark
end

--- Register autocmd to reapply extmarks when a relevant buffer is opened for the first time
---@param mgr MarkManager
local new_buf_cb = function(mgr)
	vim.api.nvim_create_autocmd("BufNew", {
		callback = function(ctx)
			if mgr.file_set[ctx.file] then
				-- print("Matched new buf:", ctx.file)
				for istack, stack in ipairs(mgr.stacks) do
					for imark, mark in ipairs(stack.marks) do
						if mark.file == ctx.file then
							mgr.stacks[istack].marks[imark] = set_extmark(mark, ctx.buf, false, imark) -- TODO replace show_status_col value here
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
---@param mgr MarkManager
---@param args PersistMarksArgs
local persist_mark_updates = function(mgr, args)
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
				for _, stack in pairs(mgr.stacks) do
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

---@param stacks PhysicalStack[]
---@param persist_args PersistMarksArgs
---@return MarkManager
MarkManager.new = function(stacks, persist_args)
	local self = setmetatable({}, MarkManager)
	self.stacks = {}
	self.file_set = {}
	self.mark_index = 0
	for _, stack in ipairs(stacks) do
		---@type MarkStack
		local newstack = {
			name = stack.name,
			marks = {},
		}
		for _, mark in ipairs(stack.bookmarks) do
			self.file_set[mark.file] = true
			---@type Mark
			local newmark = util.copy_tbl(mark)
			self.mark_index = self.mark_index + 1
			newmark.mark_id = self.mark_index
			table.insert(newstack.marks, newmark)
		end
		table.insert(self.stacks, newstack)
	end

	new_buf_cb(self)
	persist_mark_updates(self, persist_args)

	return self
end

return MarkManager

local M = {}

--- Clears the "spelunk" extmark from all open buffers.
---@return nil
local clear_extmarks = function()
	local ns_id = vim.api.nvim_create_namespace("spelunk")
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
		end
	end
end

--- Only show the marks belonging to the current stack.
---@param stack MarkStack
---@return nil
M.set_extmarks_from_stack = function(stack)
	clear_extmarks()
	local ns_id = vim.api.nvim_create_namespace("spelunk")

	for mark_idx, mark in ipairs(stack.marks) do
		local bufnr = vim.fn.bufnr(mark.file, true) -- get buffer number, load if needed
		if bufnr and vim.api.nvim_buf_is_loaded(bufnr) then
			local opts = {
				strict = false,
				right_gravity = true,
				sign_text = tostring(mark_idx),
			}

			local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, mark.line - 1, mark.col - 1, opts)
			mark.bufnr = bufnr
			mark.extmark_id = mark_id
		end
	end
end

---@param mark PhysicalBookmark
---@return string
M.get_treesitter_context = function(mark)
	local bufnr = vim.fn.bufnr(mark.file)
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok or not parser then
		return ""
	end
	local tree = parser:parse()[1]
	local root = tree:root()
	---@param arr string[]
	---@param s string
	---@return boolean
	local has = function(arr, s)
		for _, v in pairs(arr) do
			if v == s then
				return true
			end
		end
		return false
	end
	---@param node TSNode
	---@return string | nil
	local get_node_name = function(node)
		if not node then
			return nil
		end
		---@param n TSNode | nil
		---@return string | nil
		local get_txt = function(n)
			if not n then
				return nil
			end
			local start_row, start_col, end_row, end_col = n:range()
			return vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})[1]
		end
		---@type TSNode | nil
		local identifier
		for i = 0, node:named_child_count() - 1 do
			local child = node:named_child(i)
			if not child then
				goto continue
			end
			if
				has({
					"identifier",
					"name",
					"function_name",
					"class_name",
					"field_identifier",
					"dot_index_expression",
					"method_index_expression",
				}, child:type())
			then
				identifier = child
			end
			::continue::
		end
		return get_txt(identifier)
	end
	local node_names = {}
	local current_node = root:named_descendant_for_range(mark.line, mark.col, mark.line, mark.col)
	while current_node do
		local node_type = current_node:type()
		if
			has({
				-- Class-likes
				"class_definition",
				"class_declaration",
				"struct_definition",
				"class",
				-- Function-likes
				"function_definition",
				"function_declaration",
				"method_definition",
				"method_declaration",
				"function",
			}, node_type)
		then
			local node_name = get_node_name(current_node)
			if node_name then
				table.insert(node_names, node_name)
			end
		end
		current_node = current_node:parent()
	end
	---@param t table
	---@return table
	local reverse_table = function(t)
		local reversed = {}
		for i = #t, 1, -1 do
			table.insert(reversed, t[i])
		end
		return reversed
	end
	return table.concat(reverse_table(node_names), ".")
end

---@param tbl table
---@return table
M.copy_tbl = function(tbl)
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = v
	end
	return copy
end

---@param file_path string
---@return integer
M.line_count = function(file_path)
	local uv = vim.loop
	local fd = uv.fs_open(file_path, "r", 438) -- 438 = 0666 permissions
	if not fd then
		vim.notify("[spelunk.nvim] File not found: " .. file_path, vim.log.levels.ERROR)
		return 0
	end

	local stat = uv.fs_fstat(fd)
	if not stat then
		uv.fs_close(fd)
		return 0
	end

	local data = uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)
	if not data then
		return 0
	end

	local count = 0
	for _ in data:gmatch("\n") do
		count = count + 1
	end

	-- add 1 if file doesn't end with newline but has content
	if #data > 0 and data:sub(-1) ~= "\n" then
		count = count + 1
	end

	return count
end

return M

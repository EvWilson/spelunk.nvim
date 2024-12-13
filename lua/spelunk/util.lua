local M = {}

---@param mark VirtualBookmark
---@return string
M.get_treesitter_context = function(mark)
	local ok, parser = pcall(vim.treesitter.get_parser, mark.bufnr)
	if not ok then
		return '[spelunk.nvim] get_treesitter_context failed to set up parser: ' .. parser
	end
	local tree = parser:parse()[1]
	local root = tree:root()
	local node_at_cursor = root:named_descendant_for_range(mark.line, mark.col, mark.line, mark.col)
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
	local get_node_name = function(node)
		if not node then return nil end
		---@param n TSNode | nil
		---@return string | nil
		local get_txt = function(n)
			if not n then return nil end
			local start_row, start_col, end_row, end_col = n:range()
			return vim.api.nvim_buf_get_text(
				mark.bufnr,
				start_row,
				start_col,
				end_row,
				end_col,
				{}
			)[1]
		end
		---@type TSNode | nil
		local identifier
		for i = 0, node:named_child_count() - 1 do
			local child = node:named_child(i)
			if not child then goto continue end
			if has({
					'identifier',
					'name',
					'function_name',
					'class_name',
					'field_identifier'
				}, child:type()) then
				identifier = child
			end
			::continue::
		end
		return get_txt(identifier)
	end
	local node_names = {}
	local current_node = node_at_cursor
	while current_node do
		local node_type = current_node:type()
		if has({
				-- Class-likes
				'class_definition',
				'class_declaration',
				'struct_definition',
				'class',
				-- Function-likes
				'function_definition',
				'function_declaration',
				'method_definition',
				'method_declaration',
				'function'
			}, node_type) then
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
	return table.concat(reverse_table(node_names), '.')
end

---@param tbl table | nil
---@return integer
M.tbllen = function(tbl)
	if tbl == nil then
		return 0
	end
	local count = 0
	for _ in pairs(tbl) do count = count + 1 end
	return count
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

return M

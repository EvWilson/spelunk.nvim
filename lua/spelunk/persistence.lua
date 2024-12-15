local M = {}

local statepath = vim.fn.stdpath('state')
if type(statepath) == 'table' then
	statepath = statepath[1]
end
local state_dir = vim.fs.joinpath(statepath, 'spelunk')
local cwd_str = (vim.fn.getcwd() .. '.lua'):gsub('[/\\:*?\"<>|]', '_')
local path = vim.fs.joinpath(state_dir, cwd_str)

---@return string
local function exportstring(s)
	return string.format('%q', s)
end

-- savetbl and loadtbl taken from:
-- http://lua-users.org/wiki/SaveTableToFile

---@param tbl PhysicalStack[]
---@param filename string
local function savetbl(tbl, filename)
	local charS, charE = '   ', '\n'
	local file, err = io.open(filename, 'wb')
	if err then return end
	if not file then return end
	local tables, lookup = { tbl }, { [tbl] = 1 }
	file:write('return {' .. charE)
	for idx, t in ipairs(tables) do
		file:write('-- Table: {' .. idx .. '}' .. charE)
		file:write('{' .. charE)
		local thandled = {}
		for i, v in ipairs(t) do
			thandled[i] = true
			local stype = type(v)
			if stype == 'table' then
				if not lookup[v] then
					table.insert(tables, v)
					lookup[v] = #tables
				end
				file:write(charS .. '{' .. lookup[v] .. '},' .. charE)
			elseif stype == 'string' then
				file:write(charS .. exportstring(v) .. ',' .. charE)
			elseif stype == 'number' then
				file:write(charS .. tostring(v) .. ',' .. charE)
			end
		end

		for i, v in pairs(t) do
			if (not thandled[i]) then
				local str = ''
				local stype = type(i)
				if stype == 'table' then
					if not lookup[i] then
						table.insert(tables, i)
						lookup[i] = #tables
					end
					str = charS .. '[{' .. lookup[i] .. '}]='
				elseif stype == 'string' then
					str = charS .. '[' .. exportstring(i) .. ']='
				elseif stype == 'number' then
					str = charS .. '[' .. tostring(i) .. ']='
				end
				if str ~= '' then
					stype = type(v)
					if stype == 'table' then
						if not lookup[v] then
							table.insert(tables, v)
							lookup[v] = #tables
						end
						file:write(str .. '{' .. lookup[v] .. '},' .. charE)
					elseif stype == 'string' then
						file:write(str .. exportstring(v) .. ',' .. charE)
					elseif stype == 'number' then
						file:write(str .. tostring(v) .. ',' .. charE)
					end
				end
			end
		end
		file:write('},' .. charE)
	end
	file:write('}')
	file:close()
end

---@return PhysicalStack[] | nil
local function loadtbl(sfile)
	local ftables, err = loadfile(sfile)
	if err then return nil end
	if not ftables then return nil end
	local tables = ftables()
	for idx = 1, #tables do
		local tolinki = {}
		for i, v in pairs(tables[idx]) do
			if type(v) == 'table' then
				tables[idx][i] = tables[v[1]]
			end
			if type(i) == 'table' and tables[i[1]] then
				table.insert(tolinki, { i, tables[i[1]] })
			end
		end
		for _, v in ipairs(tolinki) do
			tables[idx][v[2]], tables[idx][v[1]] = tables[idx][v[1]], nil
		end
	end
	return tables[1]
end

---@param tbl PhysicalStack[]
function M.save(tbl)
	if vim.fn.isdirectory(state_dir) == 0 then
		vim.fn.mkdir(state_dir, 'p')
	end
	savetbl(tbl, path)
end

---@return PhysicalStack[] | nil
function M.load()
	local tbl = loadtbl(path)
	if tbl == nil then
		return nil
	end

	-- TODO: Remove this eventually
	-- Stored marks did not originally have column field, this is a soft migration helper
	-- Next, marks did not originally have a meta field
	for _, v in pairs(tbl) do
		for _, mark in pairs(v.bookmarks) do
			if mark.col == nil then
				mark.col = 0
			end
			if mark.meta == nil then
				mark.meta = {}
			end
		end
	end

	return tbl
end

return M

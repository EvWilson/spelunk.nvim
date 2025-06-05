local M = {}

--@type string
local state_dir
--@type string
local path

---@return string
local exportstring = function(s)
	return string.format("%q", s)
end

-- savetbl and loadtbl taken from:
-- http://lua-users.org/wiki/SaveTableToFile

---@param tbl PhysicalStack[]
---@param filename string
local savetbl = function(tbl, filename)
	local charS, charE = "   ", "\n"
	local file, err = io.open(filename, "wb")
	if err then
		return
	end
	if not file then
		return
	end
	local tables, lookup = { tbl }, { [tbl] = 1 }
	file:write("return {" .. charE)
	for idx, t in ipairs(tables) do
		file:write("-- Table: {" .. idx .. "}" .. charE)
		file:write("{" .. charE)
		local thandled = {}
		for i, v in ipairs(t) do
			thandled[i] = true
			local stype = type(v)
			if stype == "table" then
				if not lookup[v] then
					table.insert(tables, v)
					lookup[v] = #tables
				end
				file:write(charS .. "{" .. lookup[v] .. "}," .. charE)
			elseif stype == "string" then
				file:write(charS .. exportstring(v) .. "," .. charE)
			elseif stype == "number" then
				file:write(charS .. tostring(v) .. "," .. charE)
			end
		end

		for i, v in pairs(t) do
			if not thandled[i] then
				local str = ""
				local stype = type(i)
				if stype == "table" then
					if not lookup[i] then
						table.insert(tables, i)
						lookup[i] = #tables
					end
					str = charS .. "[{" .. lookup[i] .. "}]="
				elseif stype == "string" then
					str = charS .. "[" .. exportstring(i) .. "]="
				elseif stype == "number" then
					str = charS .. "[" .. tostring(i) .. "]="
				end
				if str ~= "" then
					stype = type(v)
					if stype == "table" then
						if not lookup[v] then
							table.insert(tables, v)
							lookup[v] = #tables
						end
						file:write(str .. "{" .. lookup[v] .. "}," .. charE)
					elseif stype == "string" then
						file:write(str .. exportstring(v) .. "," .. charE)
					elseif stype == "number" then
						file:write(str .. tostring(v) .. "," .. charE)
					end
				end
			end
		end
		file:write("}," .. charE)
	end
	file:write("}")
	file:close()
end

---@return PhysicalStack[] | nil
local loadtbl = function(sfile)
	local ftables, err = loadfile(sfile)
	if err then
		return nil
	end
	if not ftables then
		return nil
	end
	local tables = ftables()
	for idx = 1, #tables do
		local tolinki = {}
		for i, v in pairs(tables[idx]) do
			if type(v) == "table" then
				tables[idx][i] = tables[v[1]]
			end
			if type(i) == "table" and tables[i[1]] then
				table.insert(tolinki, { i, tables[i[1]] })
			end
		end
		for _, v in ipairs(tolinki) do
			tables[idx][v[2]], tables[idx][v[1]] = tables[idx][v[1]], nil
		end
	end
	return tables[1]
end

--@param name string
local sanitize_git_branch = function(name)
	if not name or name == "" then
		return ""
	end

	local problematic_chars = {
		"/",
		"\\",
		":",
		"*",
		"?",
		"<",
		">",
		"|",
		'"',
		"#",
		"%",
	}

	local sanitized = name
	for _, char in pairs(problematic_chars) do
		sanitized = sanitized:gsub(vim.pesc(char), "_")
	end

	-- Collapse repeated spaces and underscores
	sanitized = sanitized:gsub("%s+", "_")
	sanitized = sanitized:gsub("_+", "_")

	-- Trim leading and trailing spaces/underscores
	sanitized = sanitized:gsub("^[%s_]+", "")
	sanitized = sanitized:gsub("[%s_]+$", "")

	if sanitized == "" then
		sanitized = "sanitized"
	end

	return sanitized
end

--@return string | nil
local function get_git_branch()
	local ok, result = pcall(function()
		return vim.system({ "git", "branch", "--show-current" }, { cwd = vim.fn.getcwd() }):wait()
	end)
	if not ok then
		vim.notify("[spelunk.nvim] Error retrieving git branch for persistence")
		return nil
	end
	if result and result.code == 0 then
		local branch = vim.trim(result.stdout)
		return branch ~= "" and branch or nil
	end
	return nil
end

--@param usebranches boolean
function M.setup(usebranches)
	local statepath = vim.fn.stdpath("state")
	if type(statepath) == "table" then
		statepath = statepath[1]
	end
	state_dir = vim.fs.joinpath(statepath, "spelunk")
	local cwd_str = vim.fn.getcwd():gsub('[/\\:*?"<>|]', "_")
	local branch = ""
	if usebranches then
		local maybe_branch = sanitize_git_branch(get_git_branch())
		if maybe_branch then
			branch = maybe_branch
		end
	end
	path = vim.fs.joinpath(state_dir, cwd_str .. branch .. ".lua")
end

---@param tbl PhysicalStack[]
function M.save(tbl)
	if vim.fn.isdirectory(state_dir) == 0 then
		vim.fn.mkdir(state_dir, "p")
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

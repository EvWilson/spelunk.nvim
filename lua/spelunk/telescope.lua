local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local M = {}

local function strip_prefix()
	local cwd = vim.fn.getcwd() .. '/'
	---@param str string
	return function(str)
		if string.sub(str, 1, #cwd) == cwd then
			return string.sub(str, #cwd + 1)
		end
	end
end

---@param prompt string
---@param data any
---@param cb function
M.search_stacks = function(prompt, data, cb)
	local opts = {}
	local strip = strip_prefix()

	pickers.new(opts, {
		prompt_title = prompt,
		finder = finders.new_table {
			results = data,
			entry_maker = function(entry)
				local display_str = string.format('%s.%s:%d', entry.stack, strip(entry.file), entry.line)
				return {
					value = entry,
					display = display_str,
					ordinal = display_str,
				}
			end
		},
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				cb(selection.value.file, selection.value.line)
			end)
			return true
		end,
	}):find()
end


return M

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local previewers = require('telescope.previewers')

local M = {}

local file_previewer = previewers.new_buffer_previewer({
	title = 'Preview',
	get_buffer_by_name = function(_, entry)
		return entry.filename
	end,
	define_preview = function(self, entry)
		local lines = vim.fn.readfile(entry.value.file)
		vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

		local ft = vim.filetype.match({ filename = entry.value.file })
		if ft then
			vim.bo[self.state.bufnr].filetype = ft
		end

		vim.schedule(function()
			vim.api.nvim_win_set_cursor(self.state.winid, { entry.value.line, 0 })
			-- Center the view on the line
			local top = vim.fn.line('w0', self.state.winid)
			local bot = vim.fn.line('w$', self.state.winid)
			local center = math.floor(top + (bot - top) / 2)
			vim.api.nvim_buf_add_highlight(self.state.bufnr, -1, 'Search', center - 1, 0, -1)
		end)
	end,
})

---@param prompt string
---@param data FullBookmark[]
---@param cb fun(file: string, line: integer, col: integer, split: string|nil)
M.search_marks = function(prompt, data, cb)
	local opts = {}

	pickers.new(opts, {
		prompt_title = prompt,
		finder = finders.new_table {
			results = data,
			---@param entry FullBookmark
			entry_maker = function(entry)
				local display_str = require('spelunk.util').full_bookmark_to_string(entry)
				return {
					value = entry,
					display = display_str,
					ordinal = display_str,
				}
			end
		},
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, _)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				cb(selection.value.file, selection.value.line, selection.value.col)
			end)
			return true
		end,
		previewer = file_previewer,
	}):find()
end

---@param prompt string
---@param data PhysicalStack[]
---@param cb fun(data: PhysicalStack)
M.search_stacks = function(prompt, data, cb)
	local opts = {}

	pickers.new(opts, {
		prompt_title = prompt,
		finder = finders.new_table {
			results = data,
			entry_maker = function(entry)
				local display_str = entry.name
				return {
					value = entry,
					display = display_str,
					ordinal = display_str,
				}
			end
		},
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, _)
			actions.select_default:replace(function()
				local selection = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				cb(selection.value)
			end)
			return true
		end,
	}):find()
end

return M

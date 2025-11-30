local status_ok, _ = pcall(require, "telescope")
if not status_ok then
	vim.notify("[spelunk.nvim] telescope.nvim is not installed, cannot be used for searching", vim.log.levels.ERROR)
	return false
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

local util = require("spelunk.fuzzy.util")

local preview_ns_id = vim.api.nvim_create_namespace("spelunk")

local M = {}

local file_previewer = previewers.new_buffer_previewer({
	title = "Preview",
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
			vim.api.nvim_buf_set_extmark(self.state.bufnr, preview_ns_id, entry.value.line - 1, 0, {
				end_row = entry.value.line,
				end_col = 0,
				hl_group = "Search",
			})
		end)
	end,
})

---@param opts SearchMarksOpts
M.search_marks = function(opts)
	local selections = {}
	pickers
		.new(selections, {
			prompt_title = opts.prompt,
			finder = finders.new_table({
				results = opts.data,
				---@param entry FullBookmark
				entry_maker = function(entry)
					local display_str = string.format("%s.%s", entry.stack, opts.display_fn(entry))
					return {
						value = entry,
						display = display_str,
						ordinal = display_str,
					}
				end,
			}),
			sorter = conf.generic_sorter(selections),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					opts.select_fn(selection.value.file, selection.value.line, selection.value.col)
				end)
				return true
			end,
			previewer = file_previewer,
		})
		:find()
end

---@param display_fn fun(mark: Mark): string
local stack_previewer = function(display_fn)
	return previewers.new_buffer_previewer({
		title = "Stack Contents",
		define_preview = function(self, entry, _)
			local lines = util.get_stack_lines(entry.value, display_fn)
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
		end,
	})
end

---@param opts SearchStacksOpts
M.search_stacks = function(opts)
	local selections = {}
	pickers
		.new(selections, {
			prompt_title = opts.prompt,
			finder = finders.new_table({
				results = opts.data,
				entry_maker = function(entry)
					local display_str = entry.name
					return {
						value = entry,
						display = display_str,
						ordinal = display_str,
					}
				end,
			}),
			sorter = conf.generic_sorter(selections),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					opts.select_fn(selection.value.name)
				end)
				return true
			end,
			previewer = stack_previewer(opts.display_fn),
		})
		:find()
end

return M

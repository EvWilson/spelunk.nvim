local M = {}

---@type "native" | "telescope" | "snacks" | "fzf-lua" | "disabled"
local selection
---@type fun(): boolean
local ui_is_open

---@param fuzzy_search_provider "native" | "telescope" | "snacks" | "fzf-lua" | "disabled"
---@param ui_open fun(): boolean
M.setup = function(fuzzy_search_provider, ui_open)
	selection = fuzzy_search_provider
	ui_is_open = ui_open
end

local provider = function()
	local opts = {
		["native"] = function()
			return require("spelunk.fuzzy.native")
		end,
		["telescope"] = function()
			---@diagnostic disable-next-line
			return require("spelunk.fuzzy.telescope")
		end,
		["snacks"] = function()
			return require("spelunk.fuzzy.snacks")
		end,
		["fzf-lua"] = function()
			return require("spelunk.fuzzy.fzf-lua")
		end,
	}
	local selected_provider = opts[selection]
	if not selected_provider then
		vim.notify(
			"[spelunk.nvim] Unrecognized fuzzy search provider value: " .. vim.inspect(selection),
			vim.log.levels.ERROR
		)
	end
	return selected_provider()
end

---@class SearchMarksOpts
---@field prompt string
---@field data FullBookmark[]
---@field select_fn fun(file: string, line: integer, col: integer, split: "vertical" | "horizontal" | nil)
---@field display_fn fun(mark: FullBookmark | Mark): string

---@param opts SearchMarksOpts
M.search_marks = function(opts)
	if selection == "disabled" then
		return
	end
	if ui_is_open() then
		vim.notify("[spelunk.nvim] Cannot search with UI open")
		return
	end
	provider().search_marks(opts)
end

---@class SearchStacksOpts
---@field prompt string
---@field data MarkStack[]
---@field select_fn fun(stack_name: string)
---@field display_fn fun(mark: Mark): string

---@param opts SearchStacksOpts
M.search_stacks = function(opts)
	if selection == "disabled" then
		return
	end
	if ui_is_open() then
		vim.notify("[spelunk.nvim] Cannot search with UI open")
		return
	end
	provider().search_stacks(opts)
end

return M

-- Registering Telescope extensions:
-- https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md
---@diagnostic disable-next-line
return require("telescope").register_extension({
	exports = {
		marks = require("spelunk").search_marks,
		current_marks = require("spelunk").search_current_marks,
		stacks = require("spelunk").search_stacks,
	},
})

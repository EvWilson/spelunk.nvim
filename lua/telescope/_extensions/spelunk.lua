-- Registering Telescope extensions:
-- https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md
return require('telescope').register_extension({
	exports = {
		marks = require('spelunk').search_marks,
		current_marks = require('spelunk').search_current_marks
	}
})

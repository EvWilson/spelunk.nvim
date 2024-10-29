local Component = require('lualine.component'):extend()

function Component:init(opts)
	Component.super:init(opts)
end

---@return string | nil
function Component:update_status()
	if package.loaded['spelunk'] == nil then
		return
	end
	local ok, spelunk = pcall(require, 'spelunk')
	if not ok then
		return
	end

	return spelunk.statusline()
end

return Component

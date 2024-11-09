# Formatting Filenames

As mentioned in the README API section, a formatting function is exposed to allow you to format filenames however you prefer.

The default formatter gives the relative path to the file:
```lua
---@type fun(abspath: string): string
function(abspath)
	return vim.fn.fnamemodify(abspath, ':~:.')
end
```

If you'd like to change this, for example to display just the basename of the filepath, add this after calling the `setup` function in your config:
```lua
require('spelunk').file_formatter = function(abspath)
	return vim.fn.fnamemodify(abspath, ':t')
end
```

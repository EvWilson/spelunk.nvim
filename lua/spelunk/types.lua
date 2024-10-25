---@class Bookmark
---@field file string
---@field line integer

---@alias BookmarkStack table<string, Bookmark[]>

---@class CreateWinOpts
---@field title string
---@field line integer
---@field col integer

---@class UpdateWinOpts
---@field cursor_index integer
---@field title string
---@field lines string[]
---@field bookmark Bookmark

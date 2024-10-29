---@class Bookmark
---@field file string
---@field line integer

---@alias BookmarkStack table<string, Bookmark[]>

---@class CreateWinOpts
---@field title string
---@field line integer
---@field col integer
---@field minwidth integer
---@field minheight integer

---@class UpdateWinOpts
---@field cursor_index integer
---@field title string
---@field lines string[]
---@field bookmark Bookmark

---@class BaseDimensions
---@field col_width integer
---@field standard_width integer
---@field standard_height integer

---@class WindowCoords
---@field base BaseDimensions
---@field line integer
---@field col integer

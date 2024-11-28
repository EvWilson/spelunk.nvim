---@class Bookmark
---@field file string
---@field line integer
---@field col integer

---@class FullBookmark
---@field stack string
---@field file string
---@field line integer
---@field col integer

---@class BookmarkStack
---@field name string
---@field bookmarks Bookmark[]

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
---@field max_stack_size integer

---@class BaseDimensions
---@field width integer
---@field height integer

---@class WindowCoords
---@field base BaseDimensions
---@field line integer
---@field col integer

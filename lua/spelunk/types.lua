---@class PhysicalBookmark
---@field file string
---@field line integer
---@field col integer

---@class FullBookmark
---@field stack string
---@field file string
---@field line integer
---@field col integer

---@class PhysicalStack
---@field name string
---@field bookmarks PhysicalBookmark[]

---@class VirtualBookmark
---@field file string
---@field line integer
---@field col integer
---@field bufnr integer
---@field mark_id integer

---@class VirtualStack
---@field name string
---@field bookmarks VirtualBookmark[]

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
---@field bookmark VirtualBookmark
---@field max_stack_size integer

---@class BaseDimensions
---@field width integer
---@field height integer

---@class WindowCoords
---@field base BaseDimensions
---@field line integer
---@field col integer

---@class LayoutProvider
---@field bookmark_dimensions fun(): WindowCoords
---@field preview_dimensions fun(): WindowCoords
---@field help_dimensions fun(): WindowCoords

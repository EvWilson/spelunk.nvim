-- Mark management types

---@class VirtualBookmark
---@field file string
---@field line integer
---@field col integer
---@field bufnr integer
---@field mark_id integer
---@field meta MarkMeta

---@class VirtualBookmarkWithStack
---@field stack string
---@field file string
---@field line integer
---@field col integer
---@field bufnr integer
---@field mark_id integer
---@field meta MarkMeta

---@class VirtualStack
---@field name string
---@field bookmarks VirtualBookmark[]

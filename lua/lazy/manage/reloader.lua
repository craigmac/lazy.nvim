local Cache = require("lazy.core.cache")
local Config = require("lazy.core.config")
local Util = require("lazy.util")
local Plugin = require("lazy.core.plugin")

local M = {}

---@type table<string, CacheHash>
M.files = {}

---@type vim.loop.Timer
M.timer = nil
M.main = nil
M.root = nil

function M.enable()
  if M.timer then
    M.timer:stop()
  end
  if type(Config.spec) == "string" then
    M.timer = vim.loop.new_timer()
    M.root = vim.fn.stdpath("config") .. "/lua/" .. Config.spec:gsub("%.", "/")
    M.main = vim.loop.fs_stat(M.root .. ".lua") and (M.root .. ".lua") or (M.root .. "/init.lua")
    M.check(true)
    M.timer:start(2000, 2000, M.check)
  end
end

function M.disable()
  if M.timer then
    M.timer:stop()
    M.timer = nil
  end
end

function M.check(start)
  ---@type table<string,true>
  local checked = {}
  ---@type {file:string, what:string}[]
  local changes = {}

  -- spec is a module
  local function check(_, modpath)
    checked[modpath] = true
    local hash = Cache.hash(modpath)
    if hash then
      if M.files[modpath] then
        if not Cache.eq(M.files[modpath], hash) then
          M.files[modpath] = hash
          table.insert(changes, { file = modpath, what = "changed" })
        end
      else
        M.files[modpath] = hash
        table.insert(changes, { file = modpath, what = "added" })
      end
    end
  end

  check(nil, M.main)
  Util.lsmod(M.root, check)

  for file in pairs(M.files) do
    if not checked[file] then
      table.insert(changes, { file = file, what = "deleted" })
      M.files[file] = nil
    end
  end

  if not (start or #changes == 0) then
    vim.schedule(function()
      local lines = { "# Config Change Detected. Reloading...", "" }
      for _, change in ipairs(changes) do
        table.insert(lines, "- **" .. change.what .. "**: `" .. vim.fn.fnamemodify(change.file, ":p:~:.") .. "`")
      end
      Util.warn(lines)
      Plugin.load()
      vim.cmd([[do User LazyRender]])
    end)
  end
end

return M

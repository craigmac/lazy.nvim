local Config = require("lazy.core.config")
local Runner = require("lazy.manage.runner")
local Plugin = require("lazy.core.plugin")

local M = {}

---@class ManagerOpts
---@field wait? boolean
---@field clear? boolean
---@field show? boolean
---@field mode? string
---@field plugins? LazyPlugin[]
---@field concurrency? number

---@param ropts RunnerOpts
---@param opts? ManagerOpts
function M.run(ropts, opts)
  opts = opts or {}

  if opts.plugins then
    ropts.plugins = opts.plugins
  end

  ropts.concurrency = ropts.concurrency or opts.concurrency or Config.options.concurrency

  if opts.clear then
    M.clear()
  end

  if opts.show ~= false then
    vim.schedule(function()
      require("lazy.view").show(opts.mode)
    end)
  end

  ---@type Runner
  local runner = Runner.new(ropts)
  runner:start()

  vim.cmd([[do User LazyRender]])

  -- wait for post-install to finish
  runner:wait(function()
    vim.cmd([[do User LazyRender]])
    Plugin.update_state()
    require("lazy.manage.checker").fast_check()
  end)

  if opts.wait then
    runner:wait()
  end
  return runner
end

---@param opts? ManagerOpts
function M.install(opts)
  return M.run({
    pipeline = {
      "git.clone",
      "git.checkout",
      "plugin.docs",
      "wait",
      "plugin.build",
    },
    plugins = function(plugin)
      return plugin.url and not plugin._.installed
    end,
  }, opts):wait(function()
    require("lazy.help").update()
  end)
end

---@param opts? ManagerOpts|{lockfile?:boolean}
function M.update(opts)
  opts = opts or {}
  return M.run({
    pipeline = {
      "git.branch",
      "git.fetch",
      { "git.checkout", lockfile = opts.lockfile },
      "plugin.docs",
      "wait",
      "plugin.build",
      { "git.log", updated = true },
    },
    plugins = function(plugin)
      return plugin.url and plugin._.installed
    end,
  }, opts):wait(function()
    require("lazy.manage.lock").update()
    require("lazy.help").update()
  end)
end

---@param opts? ManagerOpts
function M.check(opts)
  opts = opts or {}
  return M.run({
    pipeline = {
      "git.fetch",
      "wait",
      { "git.log", check = true },
    },
    plugins = function(plugin)
      return plugin.url and plugin._.installed
    end,
  }, opts)
end

---@param opts? ManagerOpts
function M.log(opts)
  return M.run({
    pipeline = { "git.log" },
    plugins = function(plugin)
      return plugin.url and plugin._.installed
    end,
  }, opts)
end

---@param opts? ManagerOpts
function M.clean(opts)
  return M.run({
    pipeline = { "fs.clean" },
    plugins = Config.to_clean,
  }, opts)
end

function M.clear()
  Plugin.load()
  for _, plugin in pairs(Config.plugins) do
    plugin._.has_updates = nil
    plugin._.updated = nil
    plugin._.cloned = nil
    plugin._.dirty = nil
    -- clear finished tasks
    if plugin._.tasks then
      ---@param task LazyTask
      plugin._.tasks = vim.tbl_filter(function(task)
        return task:is_running()
      end, plugin._.tasks)
    end
  end
  vim.cmd([[do User LazyRender]])
end

return M

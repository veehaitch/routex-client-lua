
---Try to load `logging` from LUA_PATH first and fallback to our vendored version, if necessary
---@return table
local function findLoggingModule()
  local ok, logging = pcall(require, "logging")
  if ok then
    return logging
  else
    logging = require("routex-client.vendor.logging")
    local consoleLogger = require("routex-client.vendor.logging.console")()
    logging.defaultLogger(consoleLogger)
    return logging
  end
end

return findLoggingModule()
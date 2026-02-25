---Read random bytes from /dev/urandom
---@param nbytes number number of bytes to read
---@return string @byte string
local function urandom(nbytes)
  local f = io.open("/dev/urandom", "rb")
  assert(f, "Failed to open /dev/urandom")
  local bytes = f:read(nbytes)
  f:close()
  assert(#bytes == nbytes, "Failed to read enough bytes")
  return bytes
end

return {
  urandom = urandom
}

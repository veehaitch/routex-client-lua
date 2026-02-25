local base64 = require("routex-client.vendor.plc.base64")

---Encode with URL-safe Base64 with no padding and no wrap
---@param data binary
---@return string
local function base64_urlsafe(data)
  local res = base64
    .encode(data, true)
    :gsub("\n", "")
  return res
end

---Encode with standard Base64 with padding and no wrap
---@param data binary
---@return string
local function base64_encode(data)
  local res = base64
    .encode(data, false)
    :gsub("\n", "")
  return res
end

return {
  encode = base64_encode,
  encodeWrap = base64.encode,
  encodeUrlsafe = base64_urlsafe,
  decode = base64.decode
}

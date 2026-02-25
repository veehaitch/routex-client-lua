-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local hkdf = require("routex-client.vendor.tls13.crypto.hkdf")

---@class YAXI.Crypto.HKDF
---@field private _hkdf table
---@field private _salt string
---@field private _length integer
---@field private _info string
---@field private __index table
local HKDF = {}
HKDF.__index = HKDF

---Create a new instance
---@param hmac table
---@param length integer
---@param salt binary
---@param info binary
---@return YAXI.Crypto.HKDF
function HKDF.new(hmac, length, salt, info)
  local self = setmetatable({}, HKDF)

  self._hkdf = hkdf.hkdf(hmac)
  self._length = length
  self._salt = salt
  self._info = info

  return self
end

---@param key_material binary
---@return binary
function HKDF:_extract(key_material)
  return self._hkdf:extract(key_material, self._salt)
end

---@param prk binary pseudo random key
---@return binary
function HKDF:_expand(prk)
  return self._hkdf:expand(self._info, self._length, prk)
end

---Derive a key
---@param key_material binary
---@return binary
function HKDF:derive(key_material)
  local prk = self:_extract(key_material)
  return self:_expand(prk)
end

return { HKDF = HKDF }

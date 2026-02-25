-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Implementation of Blake2b-512 for the tls13.crypto.hmac.hash interface

local blake2b = require("routex-client.vendor.plc.blake2b")

local Blake2b512 = {
  HASH_SIZE = 64,
  BLOCK_SIZE = 128,
}
Blake2b512.__index = Blake2b512

function Blake2b512:new(outlen, key)
  local obj = setmetatable({}, self)
  obj._ctx = blake2b.init(outlen or self.HASH_SIZE, key)
  return obj
end

function Blake2b512:update(chunk)
  blake2b.update(self._ctx, chunk)
  return self
end

function Blake2b512:finish()
  return blake2b.final(self._ctx)
end

return setmetatable(Blake2b512, { __call = Blake2b512.new })

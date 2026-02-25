-- A wrapper around ec25519 to provide a Python cryptography-like interface
--
-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local curve25519 = require("routex-client.vendor.tls13.crypto.curve25519")
local random = require("routex-client.crypto.random")

---@class YAXI.Crypto.X25519PublicKey
---@field private _raw_key string
---@field private __index table
local X25519PublicKey = {}
X25519PublicKey.__index = X25519PublicKey

---Create [X25519PublicKey](lua://YAXI.YAXI.Crypto.X25519PublicKey) from bytes
---@param data string
---@return YAXI.Crypto.X25519PublicKey
function X25519PublicKey:from_public_bytes(data)
  assert(#data == 32, "data must be 32 bytes")
  local obj = setmetatable({}, self)
  obj._raw_key = data
  return obj
end

---Get the raw public bytes
---@return string
function X25519PublicKey:public_bytes_raw() return self._raw_key end

---@class YAXI.Crypto.X25519PrivateKey
---@field private _raw_key string
local X25519PrivateKey = {}
X25519PrivateKey.__index = X25519PrivateKey

---Create [X25519PrivateKey](lua://YAXI.YAXI.Crypto.X25519PrivateKey) from bytes
---@param data string
---@return YAXI.Crypto.X25519PrivateKey
function X25519PrivateKey.from_private_bytes(data)
  assert(#data == 32, "data must be 32 bytes")
  local self = setmetatable({}, X25519PrivateKey)
  self._raw_key = data
  return self
end

---Generate a [X25519PrivateKey](lua://YAXI.YAXI.Crypto.X25519PrivateKey) from random bytes
---@return YAXI.Crypto.X25519PrivateKey
function X25519PrivateKey.generate()
  local secret = random.urandom(32)
  return X25519PrivateKey.from_private_bytes(secret)
end

---Get public key
---@return YAXI.Crypto.X25519PublicKey
function X25519PrivateKey:public_key()
  local pk_raw = curve25519.x25519PublicKeyFromPrivate(self._raw_key)
  return X25519PublicKey:from_public_bytes(pk_raw)
end

---Exchange a shared key with a peer
---@param peer_public_key YAXI.Crypto.X25519PublicKey
---@return string
function X25519PrivateKey:exchange(peer_public_key)
  local sk = { private = self._raw_key }
  local pk = { public = peer_public_key:public_bytes_raw() }
  local sharedSecret, err = curve25519.deriveSharedSecret(sk, pk)
  if sharedSecret == nil then
    error(("Failed to exchange shared secret: %s"):format(err))
  end
  return sharedSecret
end

---Get the raw private bytes
---@return string
function X25519PrivateKey:private_bytes_raw()
  return self._raw_key
end

return {
  X25519PublicKey = X25519PublicKey,
  X25519PrivateKey = X25519PrivateKey
}

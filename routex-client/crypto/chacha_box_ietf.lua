-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local Blake2b512 = require("routex-client.crypto.blake2b_512")
local ChaCha20Poly1305 = require("routex-client.vendor.tls13.crypto.cipher.chacha20-poly1305").chacha20Poly1305
local HKDF = require("routex-client.crypto.hkdf").HKDF
local hmac = require("routex-client.vendor.tls13.crypto.hmac")
local util = require("routex-client.util")
local x25519 = require("routex-client.crypto.x25519")

---Generate cipher
---@param recipient_public_key YAXI.Crypto.X25519PublicKey
---@param secret_key YAXI.Crypto.X25519PrivateKey
---@param info binary
---@return table
local function gen_cipher(recipient_public_key, secret_key, info)
  local shared_secret = secret_key:exchange(recipient_public_key)
  local hmacBlake2b512 = hmac.hmac(Blake2b512)
  local hkdf_blake2b = HKDF.new(hmacBlake2b512, 32, "", info)
  assert(hkdf_blake2b ~= nil, "HKDF-Blake2b should be valid")
  local shared_key = hkdf_blake2b:derive(shared_secret)
  local cipher = ChaCha20Poly1305(shared_key)
  return cipher
end

---Compose the nonce
---@param ephemeral_pk YAXI.Crypto.X25519PublicKey
---@param recipient_public_key YAXI.Crypto.X25519PublicKey
---@return binary
local function get_seal_nonce(ephemeral_pk, recipient_public_key)
  local message = ephemeral_pk:public_bytes_raw() .. recipient_public_key:public_bytes_raw()
  local res = Blake2b512:new(12):update(message):finish()
  assert(res ~= nil, "Blake2b should produce a digest")
  return res;
end

---Compose the info
---@param ephemeral_pk YAXI.Crypto.X25519PublicKey
---@param recipient_public_key YAXI.Crypto.X25519PublicKey
---@return binary
local function get_info(ephemeral_pk, recipient_public_key)
  return ephemeral_pk:public_bytes_raw() .. recipient_public_key:public_bytes_raw()
end

---Create a sealed box
---@param recipient_public_key YAXI.Crypto.X25519PublicKey
---@param plaintext binary
---@return string
local function seal(recipient_public_key, plaintext)
  local ephemeral_secret_key = x25519.X25519PrivateKey.generate()
  local ephemeral_public_key = ephemeral_secret_key:public_key()
  local nonce = get_seal_nonce(ephemeral_public_key, recipient_public_key)
  local cipher = gen_cipher(recipient_public_key, ephemeral_secret_key,
    get_info(ephemeral_public_key, recipient_public_key))
  local ciphertext = cipher:encrypt(plaintext, nonce, "")
  local chacha_box = ephemeral_public_key:public_bytes_raw() .. ciphertext
  return chacha_box
end

---Unseal a sealed box
---@param secret_key YAXI.Crypto.X25519PrivateKey
---@param chacha_box binary
---@return binary
local function unseal(secret_key, chacha_box)
  assert(#chacha_box >= 32, "passed `chacha_box` has insufficient bytes")
  local ephemeral_public_key = x25519.X25519PublicKey:from_public_bytes(string.sub(chacha_box, 1, 32))
  local ciphertext = string.sub(chacha_box, 33)
  local public_key = secret_key:public_key()
  local nonce = get_seal_nonce(ephemeral_public_key, public_key)
  local info = get_info(ephemeral_public_key, public_key)
  local cipher = gen_cipher(ephemeral_public_key, secret_key, info)
  local plaintext = cipher:decrypt(ciphertext, nonce, "")
  return plaintext
end

---@class YAXI.Crypto.PublicKey
---@field private _key YAXI.Crypto.X25519PublicKey
---@field private __index table
local PublicKey = util.class()

---Create PublicKey from raw bytes
---@param data binary
---@return YAXI.Crypto.PublicKey
function PublicKey:from_public_bytes(data)
  local obj = setmetatable({}, self)
  obj._key = x25519.X25519PublicKey:from_public_bytes(data)
  return obj
end

---Size of the public key in bytes
---@return integer @bytes
function PublicKey.size()
  return 32
end

---Raw public bytes
---@return binary
function PublicKey:public_bytes_raw()
  return self._key:public_bytes_raw()
end

---Seal the given `plaintext` data
---@param plaintext binary
---@return binary
function PublicKey:seal(plaintext)
  return seal(self._key, plaintext)
end

---@class YAXI.Crypto.SecretKey
---@field private _key YAXI.Crypto.X25519PrivateKey
---@field private __index table
local SecretKey = {}
SecretKey.__index = SecretKey

---Generate a new random secret key
---@return YAXI.Crypto.SecretKey
function SecretKey.generate()
  local self = setmetatable({}, SecretKey)
  self._key = x25519.X25519PrivateKey.generate()
  return self
end

---Raw secrey key bytes
---@return binary
function SecretKey:bytes()
  return self._key:private_bytes_raw()
end

---Get the corresponding public key
---@return YAXI.Crypto.PublicKey
function SecretKey:public_key()
  return PublicKey:from_public_bytes(self._key:public_key():public_bytes_raw())
end

---Unseal the given `chacha_box`
---@param chacha_box binary
---@return binary
function SecretKey:unseal(chacha_box)
  return unseal(self._key, chacha_box)
end

return {
  seal = seal,
  unseal = unseal,
  SecretKey = SecretKey,
  PublicKey = PublicKey
}

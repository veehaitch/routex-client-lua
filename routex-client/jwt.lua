-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local base64 = require("routex-client.util.base64")
local json = require("routex-client.vendor.json")
local hmac = require("routex-client.vendor.tls13.crypto.hmac")
local sha2 = require("routex-client.vendor.tls13.crypto.hash.sha2")
local hmacSha256 = hmac.hmac(sha2.sha256)
local util = require("routex-client.util")

---Verify the `jwt` token signature and return the token claims.
---
---**WARNING**: This won't verify JWTs beyond its signature and `exp` claim
---@param jwt string The token to be decoded
---@param key binary? The key suitable for the `algorithm`. If `nil`, skips verification
---@param algorithm "HS256"|nil The algorithm to verify with; only HS256 is currently supported
---@param options { verifySignature: boolean, verifyExp: boolean }? Additional options
---@return table<string, any> @JWT claims
local function decode(jwt, key, algorithm, options)
  ---@diagnostic disable-next-line unneccesary-if
  if algorithm and algorithm ~= "HS256" then
    error("Currently only supports HS256")
  end

  local parts = util.split(jwt, ".")
  assert(#parts == 3, "Expected the JWT to consist of three dot-separated parts")

  -- Verify the header data
  local header_json = base64.decode(parts[1])
    or error("Could not Base64-decode the JWT header")
  local headers = json.decode(header_json)

  if headers.typ ~= "JWT" then
    error(string.format("Expected a token with a header `typ` of `JWT`, got: %s", headers.typ))
  end
  if algorithm and headers.alg ~= algorithm then
    error(string.format("Unsupported or mismatched algorithm in JWT header: %s", headers.alg))
  end

  local verifySignature = true
  if options and options.verifySignature == false then
    verifySignature = false
  end
  if verifySignature and not key then
    error("Requested JWT signature verifcation but not key given")
  end

  if verifySignature then
    local msg = string.format("%s.%s", parts[1], parts[2])
    local expected_signature = hmacSha256(msg, key)
    local actual_signature = base64.decode(parts[3])
      or error("Could not Base64-decode the JWT signature")
    if actual_signature ~= expected_signature then
      error(string.format("Failed to verify JWT signature: %s", actual_signature))
    end
  end

  local payload = base64.decode(parts[2])
    or error("Could not Base64-decode the JWT payload")
  local claims = json.decode(payload)

  local verifyExp = true
  if options and options.verifyExp == false then
    verifyExp = false
  end
  if verifyExp and claims.exp then
    local now = os.time()
    if claims.exp < now then
      error(string.format("JWT has expired: %s < %s", claims.exp, now))
    end
  end

  return claims
end

---Encode the `payload` as JWT
---@param payload table<string, any> JWT claims
---@param key binary Secret key to sign with `algorithm`
---@param algorithm "HS256" Signing algorithm; only HS256 is currently supported
---@param headers table? Extra headers apart from `alg` and `typ`
---@param null_val string? Value to replace with `null`
local function encode(payload, key, algorithm, headers, null_val)
  ---@diagnostic disable-next-line unneccesary-if
  if algorithm and algorithm ~= "HS256" then
    error("Currently only supports HS256")
  end

  local all_headers = {
    alg = algorithm,
    typ = "JWT",
  }
  for k, v in pairs(headers or {}) do
    all_headers[k] = v
  end

  local jwt_header = json.encode(all_headers)
  local jwt_header_b64 = base64.encodeUrlsafe(jwt_header)

  local jwt_payload = json.encode(payload)
  if null_val then
    null_val = string.format('"%s"', null_val)
    jwt_payload = jwt_payload:gsub(null_val, "null")
  end
  local jwt_payload_b64 = base64.encodeUrlsafe(jwt_payload)

  local msg = string.format("%s.%s", jwt_header_b64, jwt_payload_b64)
  local signature = hmacSha256(msg, key)
  local signature_b64 = base64.encodeUrlsafe(signature)

  local jwt = string.format("%s.%s", msg, signature_b64)

  return jwt
end

return {
  decode = decode,
  encode = encode,
}

-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local util = require("routex-client.util")
local json = require("routex-client.vendor.json")

local function format(method, url, body, headers)
  local lines = {
    string.format("%s %s\n", method or "<method>", url or "<url>"),
  }
  for key, value in pairs(headers) do
    if key or value then
      table.insert(lines, string.format("%s: %s", key, value))
    end
  end
  table.insert(lines, string.format("\n%s", body or "<no body>"))
  return table.concat(lines, "\n")
end

--- REQUEST IMPL ---

---@class YAXI.Http.Request
---@field method "GET"|"POST"|"PUT"|"DELETE" HTTP method
---@field url string URL
---@field data string? Body
---@field headers table<string, string> Headers
---@field follow_redirects boolean Whether the HTTP client should follow_redirects
local Request = util.class()

---Create a new instance
---@param method "GET"|"POST"|"PUT"|"DELETE" HTTP method
---@param url string URL
---@param data string? Body
---@param headers table<string, string> Headers
---@param follow_redirects boolean Whether the HTTP client should follow_redirects
---@return YAXI.Http.Request
function Request:new(method, url, data, headers, follow_redirects)
  local obj = setmetatable({}, self)
  obj.method = method
  obj.url = url
  obj.data = data
  obj.headers = {}
  for name, value in pairs(headers) do
    obj.headers[name] = value
  end
  if follow_redirects ~= nil then
    obj.follow_redirects = follow_redirects
  else
    obj.follow_redirects = true
  end
  return obj
end

function Request:toString()
  return format(self.method, self.url, self.data, self.headers)
end

---@class YAXI.Http.RequestBuilder to construct a [`Request`](lua://YAXI.Http.Request)
---@field private _method "GET"|"POST"|"PUT"|"DELETE" HTTP method
---@field private _base_url string Base URL
---@field private _url string Final URL with path
---@field private _data string? Body
---@field private _headers table<string, string> Headers
---@field private _follow_redirects boolean Whether the HTTP client should follow_redirects
local RequestBuilder = util.class()

---Create a new [`RequestBuilder`](lua://YAXI.Http.RequestBuilder).
---@param base_url string Base URL
---@return YAXI.Http.RequestBuilder
function RequestBuilder:new(base_url)
  local obj = setmetatable({}, self)
  obj._base_url = base_url
  obj._url = base_url
  obj._headers = {}
  return obj
end

--#region RequestBuilder

---Create a new [RequestBuilder](lua://YAXI.Http.RequestBuilder)
---If `base_url` is not given, uses this instance for the builder
---@param base_url string? Base URL
---@return YAXI.Http.RequestBuilder
function Request:builder(base_url)
  if base_url == nil then
    return RequestBuilder
      :new(self.url)
      :method(self.method)
      :headers(self.headers)
      :data(self.data)
      :follow_redirects(self.follow_redirects)
  else
    return RequestBuilder:new(base_url)
  end
end

---Set HTTP method
---@param method "GET"|"POST"|"PUT"|"DELETE"
---@return YAXI.Http.RequestBuilder
function RequestBuilder:method(method)
  self._method = method
  return self;
end

---Set a header. If `value` is nil, removes the entry
---@param key string Header name
---@param value string? Header value
---@return YAXI.Http.RequestBuilder
function RequestBuilder:header(key, value)
  assert(string.find(key, " ") == nil, "HTTP header names may not contain spaces")
  self._headers[key] = value
  return self
end

---Set all headers to the given table
---@param tab table<string, string>
---@return YAXI.Http.RequestBuilder
function RequestBuilder:headers(tab)
  assert(type(tab) == "table", "RequestBuilder:headers: Expected a table, got " .. type(tab))
  for key, value in pairs(tab) do
    self:header(key, value)
  end
  return self
end

---Set the body
---@param data string?
---@return YAXI.Http.RequestBuilder
function RequestBuilder:data(data)
  self._data = data
  return self
end

---Use the given table as a JSON body
---@param tab table Table to JSON serialize
---@param null_value string? Replace the given value with `null` in the JSON output
---@return YAXI.Http.RequestBuilder
function RequestBuilder:json(tab, null_value)
  local data = json.encode(tab)
  if null_value ~= nil then
    null_value = string.format('"%s"', null_value)
    data = data:gsub(null_value, "null")
  end
  self:data(data)
  self:header("content-type", "application/json")
  return self
end

---Whether the HTTP client should follow_redirects
---@return YAXI.Http.RequestBuilder
function RequestBuilder:follow_redirects(value)
  self._follow_redirects = value
  return self
end

---@return YAXI.Http.Request
function RequestBuilder:build()
  return Request:new(self._method, self._url, self._data, self._headers, self._follow_redirects)
end

function RequestBuilder:toString()
  return format(self._method, self._url, self._data, self._headers)
end

--#endregion RequestBuilder

--#region Response

---@class YAXI.Http.Response
---@field status integer
---@field headers table<string, string?>
---@field body string? Body
---@field private __index table
local Response = util.class()

---Create a new [Response](lua://Response)
---@param status integer
---@param headers table<string, string>
---@param body string? Body
---@return YAXI.Http.Response
function Response:new(status, headers, body)
  local obj = setmetatable({}, self)
  obj.status = status
  obj.headers = {}
  for name, value in pairs(headers) do
    obj.headers[name] = value
  end
  obj.body = body
  return obj
end

function Response:toString()
  return format(nil, nil, self.body, self.headers)
end

--#endregion

---@class YAXI.Http.IClient Interface class for an HTTP client
local IHttpClient = {}
IHttpClient.__index = IHttpClient


---Perform an HTTP request
---@param request YAXI.Http.Request HTTP request to perform
---@return YAXI.Http.Response
---@diagnostic disable-next-line
function IHttpClient.request(self, request)
  error("Not implemented")
end

local DefaultHttpClient = util.class(IHttpClient)

function DefaultHttpClient:new()
  local obj = setmetatable({}, self)
  -- Make sure this is in LUA_PATH
  local ok, res = pcall(require, "http.request")
  if not ok then
    error("Failed to require `http.request`. Is `http-lua` in $LUA_PATH?")
  end
  obj.httpRequest = res
  return obj
end

---Perform an HTTP request
---@param request YAXI.Http.Request HTTP request to perform
---@return YAXI.Http.Response
---@return YAXI.Http.Request
function DefaultHttpClient:request(request)
  local httpReq = self.httpRequest.new_from_uri(request.url)
  for name, value in pairs(request.headers) do
    httpReq.headers:append(name, value)
  end

  httpReq.headers:upsert(":method", request.method)

  if request.data and #request.data > 0 then
    httpReq:set_body(request.data)
  end

  httpReq.follow_redirects = request.follow_redirects

  local headers, stream = httpReq:go(10)
  if headers == nil then
    error(string.format("Failed to send request: %s", stream))
  end

  local body, err = stream:get_body_as_string()
  if not body and err then
    error(string.format("Failed reading response body: %s", err))
  end

  local status = tonumber(headers:get(":status"))
    or error("Failed to get HTTP response status")

  local response = Response:new(status, headers, body)

  return response, request
end


return {
  Request = Request,
  Response = Response,
  IHttpClient = IHttpClient,
  DefaultHttpClient = DefaultHttpClient,
}

# routex-client-lua

Pure Lua client for [YAXI's](https://yaxi.tech) Open Banking services. Requires Lua >= 5.3 and an API key, which you can get for free at [hub.yaxi.tech](https://hub.yaxi.tech).

## Installation

The easiest way to install is through LuaRocks:

```sh
luarocks install routex-client
```

## Usage

The client requires an HTTP client implementing `IHttpClient`. You can either bring your own or use the bundled `DefaultHttpClient`, which depends on the [`http`](https://luarocks.org/modules/daurnimator/http) rock:

```sh
luarocks install http
```

```lua
local routex = require("routex-client")
local http = require("routex-client.http")

local httpClient = http.DefaultHttpClient:new()
local client = routex.RoutexClient:new(httpClient, "https://api.yaxi.tech")
```

## License

[MIT](LICENSE)

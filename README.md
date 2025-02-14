# HttpCookie

[![License](https://img.shields.io/hexpm/l/http_cookie.svg)](https://github.com/reisub/http_cookie/blob/main/README.md#license)

[RFC6265](https://datatracker.ietf.org/doc/html/rfc6265)-compliant HTTP Cookie implementation for Elixir.

## Installation

The package can be installed by adding `http_cookie` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:http_cookie, "~> 0.6.0"},
    # not needed if the public suffix check is disabled
    {:public_suffix, github: "axelson/publicsuffix-elixir"}
  ]
end
```

## Usage with `Req`

HttpCookie can be used with [Req](https://github.com/wojtekmach/req) to automatically set and parse cookies in HTTP requests:

```elixir
empty_jar = HttpCookie.Jar.new()

req =
  Req.new(base_url: "https://example.com", plug: plug)
  |> HttpCookie.ReqCookieManager.attach()

%{private: %{cookie_jar: updated_jar}} = Req.get!(req, url: "/one", cookie_jar: empty_jar)
%{private: %{cookie_jar: updated_jar}} = Req.get!(req, url: "/two", cookie_jar: updated_jar)
```

## License

Copyright (c) 2025 Dino Kovač

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

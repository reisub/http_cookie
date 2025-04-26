# HttpCookie

[![CI](https://github.com/reisub/http_cookie/actions/workflows/ci.yml/badge.svg)](https://github.com/reisub/http_cookie/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/http_cookie.svg)](https://github.com/reisub/http_cookie/blob/main/LICENSE)
[![Version](https://img.shields.io/hexpm/v/http_cookie.svg)](https://hex.pm/packages/http_cookie)
[![Hex Docs](https://img.shields.io/badge/documentation-gray.svg)](https://hexdocs.pm/http_cookie)

[RFC6265](https://datatracker.ietf.org/doc/html/rfc6265)-compliant HTTP Cookie implementation for Elixir.

## Installation

The package can be installed by adding `http_cookie` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:http_cookie, "~> 0.8.0"}
  ]
end
```

## Usage

```elixir
url = URI.parse("https://example.com")

# create a cookie jar
jar = HttpCookie.Jar.new()

# when a response is received, save any cookies that might have been returned
received_headers = [{"Set-Cookie", "foo=bar"}]
jar = HttpCookie.Jar.put_cookies_from_headers(jar, url, received_headers)

# before making requests, prepare the cookie header
{:ok, cookie_header_value, jar} = HttpCookie.Jar.get_cookie_header_value(jar, url)
```

### Usage with `Req`

HttpCookie can be used with [Req](https://github.com/wojtekmach/req) to automatically set and parse cookies in HTTP requests:

```elixir
empty_jar = HttpCookie.Jar.new()

req =
  Req.new(base_url: "https://example.com", plug: plug)
  |> HttpCookie.ReqPlugin.attach()

%{private: %{cookie_jar: updated_jar}} = Req.get!(req, url: "/one", cookie_jar: empty_jar)
%{private: %{cookie_jar: updated_jar}} = Req.get!(req, url: "/two", cookie_jar: updated_jar)
```

### Usage with `Tesla`

HttpCookie can be used with [Tesla](https://github.com/elixir-tesla/tesla) to automatically set and parse cookies in HTTP requests:

```elixir
{:ok, server_pid} = HttpCookie.Jar.Server.start_link()
tesla = Tesla.client([{HttpCookie.TeslaMiddleware, jar_server: server_pid}])

Tesla.get!(tesla, "https://example.com/one")
Tesla.get!(tesla, "https://example.com/two")
```

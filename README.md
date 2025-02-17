# HttpCookie

[![License](https://img.shields.io/hexpm/l/http_cookie.svg)](https://github.com/reisub/http_cookie/blob/main/README.md#license)

[RFC6265](https://datatracker.ietf.org/doc/html/rfc6265)-compliant HTTP Cookie implementation for Elixir.

## Installation

The package can be installed by adding `http_cookie` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:http_cookie, "~> 0.6.0"},
    # not needed if the public suffix check is disabled,
    # but it's highly recommended leaving it enabled
    {:public_suffix, github: "axelson/publicsuffix-elixir"}
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
jar = Jar.put_cookies_from_headers(jar, url, received_headers)

# before making requests, prepare the cookie header
{:ok, cookie_header_value, jar} = Jar.get_cookie_header_value(jar, url)
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

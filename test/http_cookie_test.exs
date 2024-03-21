defmodule HttpCookieTest do
  use ExUnit.Case, async: true

  alias HttpCookie
  import HttpCookie.Parser, only: [latest_expiry_time: 0]

  describe "from_cookie_string/2" do
    test "sets expiry_time and persistent? flag" do
      latest_expiry_time = latest_expiry_time()

      assert %{
               expiry_time: ~U[2045-12-31 16:17:18Z],
               persistent?: true
             } = parse("foo=bar; Expires=Sun, 31-Dec-2045 16:17:18 GMT")

      assert %{
               expiry_time: expiry_time,
               persistent?: true
             } = parse("foo=bar; Max-Age=3610")

      assert DateTime.diff(expiry_time, DateTime.utc_now(), :minute) == 60

      assert %{
               expiry_time: ^latest_expiry_time,
               persistent?: false
             } = parse("foo=bar")
    end

    test "sets domain and host_only? flag" do
      url = "https://sub.example.com"

      assert %{
               domain: "example.com",
               host_only?: false
             } = parse("foo=bar; Domain=example.com", url)

      assert %{
               domain: "sub.example.com",
               host_only?: true
             } = parse("foo=bar", url)
    end

    test "sets path" do
      assert %{
               path: "/some/path/"
             } = parse("foo=bar; Path=/some/path/")

      assert %{
               path: "/"
             } = parse("foo=bar")
    end

    test "sets secure_only? flag" do
      assert %{secure_only?: true} = parse("foo=bar; Secure")
      assert %{secure_only?: false} = parse("foo=bar")
    end

    test "sets http_only? flag" do
      assert %{http_only?: true} = parse("foo=bar; HttpOnly")
      assert %{http_only?: false} = parse("foo=bar")
    end

    test "rejects 'supercookies' by default" do
      url = URI.parse("https://example.co.uk")

      assert {:error, :cookie_domain_public_suffix} =
               HttpCookie.from_cookie_string("foo=bar; Domain=co.uk", url)
    end

    test "allows 'supercookies' when reject_public_suffixes: false" do
      url = URI.parse("https://example.co.uk")
      opts = [reject_public_suffixes: false]

      assert {:ok, _cookie} =
               HttpCookie.from_cookie_string("foo=bar; Domain=co.uk", url, opts)
    end

    test "parses netscape style pre-RFC cookie" do
      set_cookie_header = ~s(foo="bar"; Version="1"; Path="/acme")

      # RFC 6265 doesn't include support for pre-RFC semantics,
      # but the cookies should still succeed parsing
      assert %{
               name: "foo",
               value: ~s("bar"),
               domain: "example.com",
               path: "/"
             } = parse(set_cookie_header)
    end

    test "parses RFC 2109 cookie" do
      set_cookie_header =
        ~s(foo=bar; Version="1"; Max-Age=3600; Path=/home; Domain=example.com; Comment=christmas cracker)

      assert %{
               name: "foo",
               value: "bar",
               domain: "example.com",
               path: "/home"
             } = parse(set_cookie_header)
    end

    test "parses RFC 2965 cookie" do
      set_cookie_header =
        ~s(foo=bar; Version="1"; Max-Age=3600; Path=/home; Domain=example.com; Port="443"; Discard)

      # RFC 6265 doesn't include support for RFC 2965 "Discard" property,
      # so the cookie isn't discarded
      assert %{
               name: "foo",
               value: "bar",
               domain: "example.com",
               path: "/home"
             } = parse(set_cookie_header)
    end

    test "enforces cookie size limit" do
      url = URI.parse("https://example.com")

      littany_against_fear =
        """
        I must not fear. Fear is the mind-killer. Fear is the little-death that brings total obliteration. I will face my fear. I will permit it to pass over me and through me. And when it has gone past I will turn the inner eye to see its path. Where the fear has gone there will be nothing. Only I will remain.
        """
        |> String.trim()

      huge_str =
        littany_against_fear
        |> Stream.duplicate(27)
        |> Enum.join(" ")
        |> String.split(" ")
        |> Enum.chunk_every(2)
        |> Enum.map(fn
          [k, v] -> "#{k}=#{v}"
          [k] -> "#{k}"
        end)
        |> Enum.join("; ")

      assert {:error, :cookie_exceeds_max_size} =
               HttpCookie.from_cookie_string(String.slice(huge_str, 0, 8193), url)

      assert {:ok, _} =
               HttpCookie.from_cookie_string(String.slice(huge_str, 0, 8192), url)

      assert {:ok, _} =
               HttpCookie.from_cookie_string(
                 String.slice(huge_str, 0, 8193),
                 url,
                 max_cookie_size: :infinity
               )

      assert {:error, :cookie_exceeds_max_size} =
               HttpCookie.from_cookie_string(
                 String.slice(huge_str, 0, 100),
                 url,
                 max_cookie_size: 99
               )

      assert {:ok, _} =
               HttpCookie.from_cookie_string(
                 String.slice(huge_str, 0, 99),
                 url,
                 max_cookie_size: 99
               )
    end
  end

  describe "matches_url?/2" do
    test "for host only cookie" do
      cookie = parse("foo=bar")

      assert HttpCookie.matches_url?(cookie, URI.parse("https://example.com"))
      refute HttpCookie.matches_url?(cookie, URI.parse("https://sub.example.com"))
      refute HttpCookie.matches_url?(cookie, URI.parse("https://subexample.com"))
    end

    test "for domain cookie" do
      cookie = parse("foo=bar; Domain=example.com")

      assert HttpCookie.matches_url?(cookie, URI.parse("https://example.com"))
      assert HttpCookie.matches_url?(cookie, URI.parse("https://sub.example.com"))
      refute HttpCookie.matches_url?(cookie, URI.parse("https://subexample.com"))
    end

    test "for secure cookie" do
      cookie = parse("foo=bar; Secure")

      assert HttpCookie.matches_url?(cookie, URI.parse("https://example.com"))
      refute HttpCookie.matches_url?(cookie, URI.parse("http://example.com"))
    end

    test "for path cookie" do
      cookie = parse("foo=bar; Path=/some/path")

      assert HttpCookie.matches_url?(cookie, URI.parse("https://example.com/some/path"))
      refute HttpCookie.matches_url?(cookie, URI.parse("https://example.com/some"))
      refute HttpCookie.matches_url?(cookie, URI.parse("https://example.com/some/other"))
      refute HttpCookie.matches_url?(cookie, URI.parse("https://example.com/other"))
    end

    test "for secure host only path cookie" do
      cookie = parse("foo=bar; Path=/some/path; Secure")

      assert HttpCookie.matches_url?(cookie, URI.parse("https://example.com/some/path"))
      refute HttpCookie.matches_url?(cookie, URI.parse("https://example.com/other"))
      refute HttpCookie.matches_url?(cookie, URI.parse("http://example.com/some/path"))
      refute HttpCookie.matches_url?(cookie, URI.parse("https://sub.example.com/some/path"))
    end
  end

  test "to_header_value/1" do
    cookie = parse("foo=bar; Domain=example.com")
    assert HttpCookie.to_header_value(cookie) == "foo=bar"
  end

  test "expired?/2" do
    cookie = parse("foo=bar; Expires=Sun, 31-Dec-2045 16:17:18 GMT")

    refute HttpCookie.expired?(cookie)
    refute HttpCookie.expired?(cookie, ~U[2045-12-31 16:17:18Z])
    assert HttpCookie.expired?(cookie, ~U[2045-12-31 16:17:19Z])
  end

  defp parse(set_cookie_header, url \\ "https://example.com") do
    assert {:ok, cookie} = HttpCookie.from_cookie_string(set_cookie_header, URI.parse(url))
    cookie
  end
end

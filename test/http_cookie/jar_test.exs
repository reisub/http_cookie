defmodule HttpCookie.JarTest do
  use ExUnit.Case, async: true

  alias HttpCookie.Jar

  describe "put_cookies_from_headers/3" do
    setup :create_jar

    for header <- ~w[set-cookie Set-Cookie set-cookie2 Set-Cookie2] do
      @header header

      test "parses #{@header} header", ctx do
        headers = [
          {"Content-Type", "application/json"},
          {@header, "foo=bar"}
        ]

        jar = Jar.put_cookies_from_headers(ctx.jar, ctx.url, headers)

        assert [
                 %{
                   name: "foo",
                   value: "bar"
                 }
               ] = Jar.get_matching_cookies(jar, ctx.url)
      end
    end

    test "parses multiple set-cookie headers", ctx do
      headers = [
        {"set-cookie", "foo=bar"},
        {"Content-Type", "application/json"},
        {"set-cookie", "foo2=bar2"}
      ]

      jar = Jar.put_cookies_from_headers(ctx.jar, ctx.url, headers)

      assert [
               %{
                 name: "foo",
                 value: "bar"
               },
               %{
                 name: "foo2",
                 value: "bar2"
               }
             ] = Jar.get_matching_cookies(jar, ctx.url)
    end

    test "handles no set-cookie/set-cookie2 headers", ctx do
      headers = [
        {"Content-Type", "application/json"}
      ]

      jar = Jar.put_cookies_from_headers(ctx.jar, ctx.url, headers)
      assert Jar.get_matching_cookies(jar, ctx.url) == []
    end

    test "accumulates cookies", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      assert [
               %{
                 name: "foo",
                 value: "bar"
               }
             ] = Jar.get_matching_cookies(jar, ctx.url)

      headers = [
        {"Content-Type", "application/json"},
        {"Set-Cookie", "foo2=bar2"}
      ]

      jar = Jar.put_cookies_from_headers(jar, ctx.url, headers)

      assert [
               %{
                 name: "foo",
                 value: "bar"
               },
               %{
                 name: "foo2",
                 value: "bar2"
               }
             ] = Jar.get_matching_cookies(jar, ctx.url)
    end

    for attribute <- ["expires=Thu, 10 Apr 1980 16:33:12 GMT", "max-age=0", "max-age=-3600"] do
      @attribute attribute

      test "attr `#{@attribute}` expires an existing cookie", ctx do
        {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
        jar = Jar.put_cookie(ctx.jar, cookie)

        assert [
                 %{
                   name: "foo",
                   value: "bar"
                 }
               ] = Jar.get_matching_cookies(jar, ctx.url)

        headers = [
          {"Content-Type", "application/json"},
          {"Set-Cookie", "foo=bar; #{@attribute}"}
        ]

        jar = Jar.put_cookies_from_headers(jar, ctx.url, headers)
        assert Jar.get_matching_cookies(jar, ctx.url) == []
      end
    end

    test "overwriting a cookie keeps the original creation time", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
      cookie = %{cookie | creation_time: ~U[1999-12-25 12:00:00Z]}
      jar = Jar.put_cookie(ctx.jar, cookie)

      headers = [
        {"Content-Type", "application/json"},
        {"Set-Cookie", "foo=bar2"}
      ]

      jar = Jar.put_cookies_from_headers(jar, ctx.url, headers)

      assert [
               %{
                 name: "foo",
                 value: "bar2",
                 creation_time: ~U[1999-12-25 12:00:00Z]
               }
             ] = Jar.get_matching_cookies(jar, ctx.url)
    end

    test "respects default limit for per-domain cookies", ctx do
      # simulates adding cookies one by one from 101 requests
      jar =
        1..101
        |> Enum.reduce(ctx.jar, fn i, jar ->
          headers = [
            {"set-cookie", "foo#{i}=bar#{i}"}
          ]

          Jar.put_cookies_from_headers(jar, ctx.url, headers)
        end)

      assert length(Map.values(jar.cookies)) == 100

      # simulates adding 101 cookie in a single request
      headers =
        1..101
        |> Enum.map(fn i ->
          {"set-cookie", "foo#{i}=bar#{i}"}
        end)

      jar = Jar.put_cookies_from_headers(ctx.jar, ctx.url, headers)

      assert length(Map.values(jar.cookies)) == 100
    end

    test "respects limit for per-domain cookies", ctx do
      jar_with_custom_limit = %{ctx.jar | opts: [max_cookies_per_domain: 1]}

      # simulates adding cookies one by one from 2 requests
      jar =
        jar_with_custom_limit
        |> Jar.put_cookies_from_headers(ctx.url, [{"set-cookie", "foo1=bar1"}])
        |> Jar.put_cookies_from_headers(ctx.url, [{"set-cookie", "foo2=bar2"}])

      assert length(Map.values(jar.cookies)) == 1

      # simulates adding 2 cookies in a single request
      jar =
        Jar.put_cookies_from_headers(
          jar_with_custom_limit,
          ctx.url,
          [
            {"set-cookie", "foo1=bar1"},
            {"set-cookie", "foo2=bar2"}
          ]
        )

      assert length(Map.values(jar.cookies)) == 1
    end

    test "respects limit for cookies", ctx do
      headers = [
        {"set-cookie", "foo=bar"}
      ]

      # simulates adding cookies one by one from 5_001 requests
      jar =
        1..5_001
        |> Enum.reduce(ctx.jar, fn i, jar ->
          url = URI.parse("https://sub#{i}.example.com")
          Jar.put_cookies_from_headers(jar, url, headers)
        end)

      assert length(Map.values(jar.cookies)) == 5_000

      jar_with_custom_limit = %{ctx.jar | opts: [max_cookies: 1]}

      jar =
        jar_with_custom_limit
        |> Jar.put_cookies_from_headers(URI.parse("https://sub1.example.com"), headers)
        |> Jar.put_cookies_from_headers(URI.parse("https://sub2.example.com"), headers)

      assert length(Map.values(jar.cookies)) == 1
    end
  end

  describe "get_cookie_header_value/2" do
    setup :create_jar

    test "when no cookies match", ctx do
      assert Jar.get_cookie_header_value(ctx.jar, ctx.url) == {:error, :no_matching_cookies}
    end

    test "when one cookie matches", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      assert Jar.get_cookie_header_value(jar, ctx.url) == {:ok, "foo=bar"}
    end

    test "when two cookies match", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      {:ok, other_cookie} = HttpCookie.from_cookie_string("foo2=bar2", ctx.url)
      jar = Jar.put_cookie(jar, other_cookie)

      assert Jar.get_cookie_header_value(jar, ctx.url) == {:ok, "foo=bar; foo2=bar2"}
    end

    test "when the cookie is expired", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar; max-age=0", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      assert Jar.get_cookie_header_value(jar, ctx.url) == {:error, :no_matching_cookies}
    end
  end

  describe "clear_expired_cookies/1" do
    setup :create_jar

    test "removes expired cookies", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      {:ok, expired_cookie} = HttpCookie.from_cookie_string("foo2=bar2; max-age=0", ctx.url)
      jar = Jar.put_cookie(jar, expired_cookie)

      # the expired cookie is automatically removed
      assert Enum.count(jar.cookies) == 1
    end
  end

  describe "clear_session_cookies/1" do
    setup :create_jar

    test "removes session cookies", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar; max-age=3600", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      {:ok, expired_cookie} = HttpCookie.from_cookie_string("foo2=bar2", ctx.url)
      jar = Jar.put_cookie(jar, expired_cookie)

      assert Enum.count(jar.cookies) == 2

      jar = Jar.clear_session_cookies(jar)

      assert [
               %{
                 name: "foo",
                 value: "bar"
               }
             ] = Jar.get_matching_cookies(jar, ctx.url)
    end
  end

  # based on:
  # https://github.com/abarth/http-state/tree/master/tests/data/parser
  # `ietf-test-cases.json` was generated using `test_data_to_json.py`
  describe "IETF" do
    test_cases =
      __ENV__.file
      |> Path.relative_to_cwd()
      |> Path.rootname()
      |> Path.join("ietf-test-cases.json")
      |> File.read!()
      |> Jason.decode!()
      |> Enum.reject(&String.starts_with?(&1["test"], "DISABLED_"))

    for test_case <- test_cases do
      @test_case test_case

      test "#{test_case["test"]}" do
        test_name = test_name(@test_case)
        sent_to = Map.get(@test_case, "sent-to")

        request_url = request_url(test_name)
        next_request_url = next_request_url(test_name, sent_to)

        set_cookie_headers = set_cookie_headers(@test_case)
        expected_cookies = Map.fetch!(@test_case, "sent")

        jar = Jar.put_cookies_from_headers(Jar.new(), request_url, set_cookie_headers)

        actual_cookies =
          case Jar.get_cookie_header_value(jar, next_request_url) do
            {:ok, value} -> parse_cookie_header_value(value)
            {:error, :no_matching_cookies} -> []
          end

        assert actual_cookies == expected_cookies
      end
    end

    defp test_name(%{"test" => name}) do
      name
      |> String.downcase()
      |> String.replace("_", "-")
    end

    defp request_url(test_name) do
      URI.parse("http://home.example.org:8888/cookie-parser?#{test_name}")
    end

    def next_request_url(test_name, nil) do
      URI.parse("http://home.example.org:8888/cookie-parser-result?#{test_name}")
    end

    def next_request_url(test_name, sent_to) do
      URI.parse("http://home.example.org:8888/cookie-parser-result?#{test_name}")
      |> URI.merge(sent_to)
    end

    defp set_cookie_headers(%{"received" => received}) do
      Enum.map(received, &{"set-cookie", &1})
    end

    defp parse_cookie_header_value(cookie_header) do
      cookie_header
      |> String.split("; ")
      |> Enum.map(fn str ->
        [name, val] = String.split(str, "=", parts: 2)

        %{
          "name" => name,
          "value" => val
        }
      end)
    end
  end

  defp create_jar(_ctx) do
    [jar: Jar.new(), url: URI.parse("https://example.com")]
  end
end

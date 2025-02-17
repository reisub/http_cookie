defmodule HttpCookie.JarTest do
  use ExUnit.Case, async: true

  alias HttpCookie.Jar

  describe "new/1 validates options" do
    test "allows valid options" do
      %Jar{} = Jar.new(max_cookies: 500, max_cookies_per_domain: 100)
      %Jar{} = Jar.new(max_cookies: :infinity, max_cookies_per_domain: :infinity)
      %Jar{} = Jar.new(cookie_opts: [max_cookie_size: 1_000, reject_public_suffixes: false])
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, "[HttpCookie.Jar] invalid option :hammer_time", fn ->
        Jar.new(hammer_time: true)
      end
    end

    test "raises on unknown HttpCookie option" do
      assert_raise ArgumentError, "[HttpCookie] invalid option :hammer_time", fn ->
        Jar.new(cookie_opts: [hammer_time: true])
      end
    end

    test "raises on invalid values" do
      assert_raise ArgumentError,
                   "[HttpCookie.Jar] invalid value for :max_cookies option: 0\n\n expected :infinity or an integer > 0",
                   fn -> Jar.new(max_cookies: 0) end

      assert_raise ArgumentError,
                   "[HttpCookie.Jar] invalid value for :max_cookies option: false\n\n expected :infinity or an integer > 0",
                   fn -> Jar.new(max_cookies: false) end

      assert_raise ArgumentError,
                   "[HttpCookie.Jar] invalid value for :max_cookies option: %{what: :now}\n\n expected :infinity or an integer > 0",
                   fn -> Jar.new(max_cookies: %{what: :now}) end

      assert_raise ArgumentError,
                   "[HttpCookie.Jar] invalid value for :max_cookies_per_domain option: 0\n\n expected :infinity or an integer > 0",
                   fn -> Jar.new(max_cookies_per_domain: 0) end

      assert_raise ArgumentError,
                   "[HttpCookie.Jar] invalid value for :max_cookies_per_domain option: false\n\n expected :infinity or an integer > 0",
                   fn -> Jar.new(max_cookies_per_domain: false) end

      assert_raise ArgumentError,
                   "[HttpCookie.Jar] invalid value for :max_cookies_per_domain option: %{what: :now}\n\n expected :infinity or an integer > 0",
                   fn -> Jar.new(max_cookies_per_domain: %{what: :now}) end
    end
  end

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

        assert {[
                  %{
                    name: "foo",
                    value: "bar"
                  }
                ], _} = Jar.get_matching_cookies(jar, ctx.url)
      end
    end

    test "parses multiple set-cookie headers", ctx do
      headers = [
        {"set-cookie", "foo=bar"},
        {"Content-Type", "application/json"},
        {"set-cookie", "foo2=bar2"}
      ]

      jar = Jar.put_cookies_from_headers(ctx.jar, ctx.url, headers)

      assert {[
                %{
                  name: "foo",
                  value: "bar"
                },
                %{
                  name: "foo2",
                  value: "bar2"
                }
              ], _} = Jar.get_matching_cookies(jar, ctx.url)
    end

    test "handles no set-cookie/set-cookie2 headers", ctx do
      headers = [
        {"Content-Type", "application/json"}
      ]

      jar = Jar.put_cookies_from_headers(ctx.jar, ctx.url, headers)
      assert {[], _} = Jar.get_matching_cookies(jar, ctx.url)
    end

    test "accumulates cookies", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      assert {[
                %{
                  name: "foo",
                  value: "bar"
                }
              ], _} = Jar.get_matching_cookies(jar, ctx.url)

      headers = [
        {"Content-Type", "application/json"},
        {"Set-Cookie", "foo2=bar2"}
      ]

      jar = Jar.put_cookies_from_headers(jar, ctx.url, headers)

      assert {[
                %{
                  name: "foo",
                  value: "bar"
                },
                %{
                  name: "foo2",
                  value: "bar2"
                }
              ], _} = Jar.get_matching_cookies(jar, ctx.url)
    end

    for attribute <- ["expires=Thu, 10 Apr 1980 16:33:12 GMT", "max-age=0", "max-age=-3600"] do
      @attribute attribute

      test "attr `#{@attribute}` expires an existing cookie", ctx do
        {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
        jar = Jar.put_cookie(ctx.jar, cookie)

        assert {[
                  %{
                    name: "foo",
                    value: "bar"
                  }
                ], _} = Jar.get_matching_cookies(jar, ctx.url)

        headers = [
          {"Content-Type", "application/json"},
          {"Set-Cookie", "foo=bar; #{@attribute}"}
        ]

        jar = Jar.put_cookies_from_headers(jar, ctx.url, headers)
        assert {[], _} = Jar.get_matching_cookies(jar, ctx.url)
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

      assert {[
                %{
                  name: "foo",
                  value: "bar2",
                  creation_time: ~U[1999-12-25 12:00:00Z]
                }
              ], _} = Jar.get_matching_cookies(jar, ctx.url)
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

      assert_domain_cookie_count(jar, "example.com", 100)

      # simulates adding 101 cookie in a single request
      headers =
        1..101
        |> Enum.map(fn i ->
          {"set-cookie", "foo#{i}=bar#{i}"}
        end)

      jar = Jar.put_cookies_from_headers(ctx.jar, ctx.url, headers)

      assert_domain_cookie_count(jar, "example.com", 100)
    end

    test "respects limit for per-domain cookies", ctx do
      jar_with_custom_limit = %{ctx.jar | opts: [max_cookies_per_domain: 2]}

      # simulates adding cookies one by one from 2 requests
      jar =
        jar_with_custom_limit
        |> Jar.put_cookies_from_headers(ctx.url, [{"set-cookie", "foo1=bar1"}])
        |> Jar.put_cookies_from_headers(ctx.url, [{"set-cookie", "foo2=bar2"}])
        |> Jar.put_cookies_from_headers(ctx.url, [{"set-cookie", "foo3=bar3"}])

      assert_domain_cookie_count(jar, "example.com", 2)

      # simulates adding 2 cookies in a single request
      jar =
        Jar.put_cookies_from_headers(
          jar_with_custom_limit,
          ctx.url,
          [
            {"set-cookie", "foo1=bar1"},
            {"set-cookie", "foo2=bar2"},
            {"set-cookie", "foo3=bar3"}
          ]
        )

      assert_domain_cookie_count(jar, "example.com", 2)
    end

    @tag :slow
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

      assert_cookie_count(jar, 5_000)

      jar_with_custom_limit = %{ctx.jar | opts: [max_cookies: 2]}

      jar =
        jar_with_custom_limit
        |> Jar.put_cookies_from_headers(URI.parse("https://sub1.example.com"), headers)
        |> Jar.put_cookies_from_headers(URI.parse("https://sub2.example.com"), headers)
        |> Jar.put_cookies_from_headers(URI.parse("https://sub3.example.com"), headers)

      assert_cookie_count(jar, 2)
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

      assert {:ok, "foo=bar", %HttpCookie.Jar{}} = Jar.get_cookie_header_value(jar, ctx.url)
    end

    test "when two cookies match", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      {:ok, other_cookie} = HttpCookie.from_cookie_string("foo2=bar2", ctx.url)
      jar = Jar.put_cookie(jar, other_cookie)

      assert {:ok, "foo=bar; foo2=bar2", %HttpCookie.Jar{}} =
               Jar.get_cookie_header_value(jar, ctx.url)
    end

    test "when the cookie is expired", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar; max-age=0", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      assert Jar.get_cookie_header_value(jar, ctx.url) == {:error, :no_matching_cookies}
    end

    test "updates last_access_time", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar", ctx.url)
      cookie = %{cookie | last_access_time: ~U[2024-04-01 12:00:00Z]}
      jar = Jar.put_cookie(ctx.jar, cookie)

      assert {:ok, "foo=bar", updated_jar} = Jar.get_cookie_header_value(jar, ctx.url)

      updated_cookie =
        updated_jar.cookies["example.com"].cookies
        |> Map.values()
        |> hd()

      assert DateTime.after?(updated_cookie.last_access_time, ~U[2024-04-01 12:00:00Z])
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
      assert {[
                %{
                  name: "foo",
                  value: "bar"
                }
              ], _} = Jar.get_matching_cookies(jar, ctx.url)
    end
  end

  describe "clear_session_cookies/1" do
    setup :create_jar

    test "removes session cookies", ctx do
      {:ok, cookie} = HttpCookie.from_cookie_string("foo=bar; max-age=3600", ctx.url)
      jar = Jar.put_cookie(ctx.jar, cookie)

      {:ok, expired_cookie} = HttpCookie.from_cookie_string("foo2=bar2", ctx.url)
      jar = Jar.put_cookie(jar, expired_cookie)

      assert_cookie_count(jar, 2)

      jar = Jar.clear_session_cookies(jar)

      assert {[
                %{
                  name: "foo",
                  value: "bar"
                }
              ], _} = Jar.get_matching_cookies(jar, ctx.url)
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
            {:ok, value, _jar} -> parse_cookie_header_value(value)
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

  defp assert_cookie_count(jar, count) do
    assert jar.cookies
           |> Map.values()
           |> Enum.flat_map(&Map.values(&1.cookies))
           |> length() == count
  end

  defp assert_domain_cookie_count(jar, domain, count) do
    assert map_size(jar.cookies[domain].cookies) == count
    assert jar.cookies[domain].count == count
  end
end

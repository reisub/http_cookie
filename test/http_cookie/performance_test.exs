defmodule HttpCookie.PerformanceTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  setup_all do
    url = URI.parse("https://example.com")

    empty_jar = HttpCookie.Jar.new()

    small_jar =
      HttpCookie.Jar.new()
      |> HttpCookie.Jar.put_cookies_from_headers(url, [
        {"set-cookie", "k1=v1"},
        {"set-cookie", "k2=v2"},
        {"set-cookie", "k3=v3"}
      ])

    one_hundred_cookie_headers = Enum.map(1..100, &{"set-cookie", "k#{&1}=v#{&1}"})

    big_jar =
      HttpCookie.Jar.new()
      |> HttpCookie.Jar.put_cookies_from_headers(
        URI.parse("https://example.com"),
        one_hundred_cookie_headers
      )
      |> HttpCookie.Jar.put_cookies_from_headers(
        URI.parse("https://sub.example.com"),
        one_hundred_cookie_headers
      )

    full_jar =
      HttpCookie.Jar.new()
      |> HttpCookie.Jar.put_cookies_from_headers(
        URI.parse("https://example.com"),
        one_hundred_cookie_headers
      )

    # simulates adding cookies one by one from 4_900 requests
    full_jar =
      1..4_900
      |> Enum.reduce(full_jar, fn i, jar ->
        url = URI.parse("https://sub#{i}.example.com")
        HttpCookie.Jar.put_cookies_from_headers(jar, url, [{"set-cookie", "foo=bar"}])
      end)

    [
      empty_jar: empty_jar,
      small_jar: small_jar,
      big_jar: big_jar,
      full_jar: full_jar
    ]
  end

  @tag :benchmark
  test "HttpCookie.from_cookie_string/2 isn't slow" do
    url = URI.parse("https://sub.example.com")

    capture_io(fn ->
      result =
        Benchee.run(
          %{
            "HttpCookie.from_cookie_string/2" => fn input ->
              HttpCookie.from_cookie_string(input, url)
            end
          },
          inputs: %{
            "minimal" => "lang=en",
            "expired" => "lang=en; max-age=0",
            "supercookie" => "lang=en; Domain=co.uk",
            "big" =>
              "lang=en; Expires=Sun, 06 Nov 2034 08:49:37 GMT; Domain=example.com ; Path=/; Secure; HttpOnly"
          },
          print: [benchmarking: false, fast_warning: false, configuration: false],
          time: 0,
          reduction_time: 1
        )

      assert max_reductions(result, "minimal") < 4_000
      assert max_reductions(result, "expired") < 4_000
      assert max_reductions(result, "supercookie") < 4_000
      assert max_reductions(result, "big") < 4_000
    end)
  end

  @tag :benchmark
  test "HttpCookie.Jar.put_cookies_from_headers/2 isn't slow", ctx do
    url = URI.parse("https://another.example.com")

    capture_io(fn ->
      result =
        Benchee.run(
          %{
            "HttpCookie.Jar.put_cookies_from_headers/2" => fn input ->
              HttpCookie.Jar.put_cookies_from_headers(input, url, [{"set-cookie", "foo=bar"}])
            end
          },
          inputs: %{
            "empty_jar" => ctx.empty_jar,
            "small_jar" => ctx.small_jar,
            "big_jar" => ctx.big_jar,
            "full_jar" => ctx.full_jar
          },
          print: [benchmarking: false, fast_warning: false, configuration: false],
          time: 0,
          reduction_time: 1
        )

      assert max_reductions(result, "empty_jar") < 2_000
      assert max_reductions(result, "small_jar") < 2_500
      assert max_reductions(result, "big_jar") < 20_000
      assert max_reductions(result, "full_jar") < 4_500_000
    end)
  end

  @tag :benchmark
  test "HttpCookie.Jar.get_cookie_header_value/2 isn't slow", ctx do
    url = URI.parse("https://example.com")

    capture_io(fn ->
      result =
        Benchee.run(
          %{
            "HttpCookie.Jar.get_cookie_header_value/2" => fn input ->
              HttpCookie.Jar.get_cookie_header_value(input, url)
            end
          },
          inputs: %{
            "empty_jar" => ctx.empty_jar,
            "small_jar" => ctx.small_jar,
            "big_jar" => ctx.big_jar,
            "full_jar" => ctx.full_jar
          },
          print: [benchmarking: false, fast_warning: false, configuration: false],
          time: 0,
          reduction_time: 1
        )

      assert max_reductions(result, "empty_jar") < 150
      assert max_reductions(result, "small_jar") < 2_500
      assert max_reductions(result, "big_jar") < 200_000
      assert max_reductions(result, "full_jar") < 3_250_000
    end)
  end

  defp max_reductions(benchee_result, input_name) do
    benchee_result.scenarios
    |> Enum.find(&(&1.input_name == input_name))
    |> get_in([
      Access.key(:reductions_data),
      Access.key(:statistics),
      Access.key(:maximum)
    ])
  end
end

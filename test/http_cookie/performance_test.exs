defmodule HttpCookie.PerformanceTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  # Budgets leave about 10% of headroom over the measured maximum reductions, so
  # a big performance regression fails the test. They were measured with the
  # Elixir/OTP in mise.toml (the CI job that runs benchmarks) and may need new
  # values when those change; a failure lists every measured value.

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
      jars: %{
        "empty_jar" => empty_jar,
        "small_jar" => small_jar,
        "big_jar" => big_jar,
        "full_jar" => full_jar
      }
    ]
  end

  @tag :benchmark
  test "HttpCookie.from_cookie_string/2 isn't slow" do
    url = URI.parse("https://sub.example.com")

    assert_reductions(
      &HttpCookie.from_cookie_string(&1, url),
      %{
        "minimal" => "lang=en",
        "expired" => "lang=en; max-age=0",
        "supercookie" => "lang=en; Domain=co.uk",
        "big" => "lang=en; Expires=Sun, 06 Nov 2034 08:49:37 GMT; Domain=example.com ; Path=/; Secure; HttpOnly",
        # the longest Domain attribute within the default max_cookie_size,
        # public suffix matching used to take quadratic time on it
        "long_domain" => "a=b; Domain=" <> String.duplicate("a.", 4_000) <> "com"
      },
      %{
        "minimal" => 410,
        "expired" => 655,
        "supercookie" => 782,
        "big" => 2_480,
        "long_domain" => 41_100
      }
    )

    # non-ASCII hosts go through IDNA, ASCII hosts skip it
    idn_url = URI.parse("https://bücher.de")

    assert_reductions(
      &HttpCookie.from_cookie_string(&1, idn_url),
      %{"idn_host" => "lang=en"},
      %{"idn_host" => 1_050}
    )
  end

  @tag :benchmark
  test "HttpCookie.Jar.put_cookies_from_headers/3 isn't slow", ctx do
    url = URI.parse("https://another.example.com")

    assert_reductions(
      &HttpCookie.Jar.put_cookies_from_headers(&1, url, [{"set-cookie", "foo=bar"}]),
      ctx.jars,
      %{
        "empty_jar" => 842,
        "small_jar" => 1_100,
        "big_jar" => 13_200,
        "full_jar" => 3_110_000
      }
    )

    # insecure responses also check that no Secure cookie gets overwritten
    http_url = URI.parse("http://another.example.com")

    assert_reductions(
      &HttpCookie.Jar.put_cookies_from_headers(&1, http_url, [{"set-cookie", "foo=bar"}]),
      Map.take(ctx.jars, ["full_jar"]),
      %{"full_jar" => 3_150_000}
    )
  end

  @tag :benchmark
  test "HttpCookie.Jar.get_cookie_header_value/2 isn't slow", ctx do
    url = URI.parse("https://example.com")

    assert_reductions(
      &HttpCookie.Jar.get_cookie_header_value(&1, url),
      ctx.jars,
      %{
        # an empty jar returns right away, 10% of headroom isn't a whole reduction
        "empty_jar" => 7,
        "small_jar" => 652,
        "big_jar" => 43_300,
        "full_jar" => 291_000
      }
    )

    # a request no cookie matches still checks every cookie
    other_url = URI.parse("https://other.org")

    assert_reductions(
      &HttpCookie.Jar.get_cookie_header_value(&1, other_url),
      Map.take(ctx.jars, ["full_jar"]),
      %{"full_jar" => 261_000}
    )
  end

  defp assert_reductions(fun, inputs, budgets) do
    assert Enum.sort(Map.keys(inputs)) == Enum.sort(Map.keys(budgets))

    {result, _output} =
      with_io(fn ->
        Benchee.run(%{"benchmark" => fun},
          inputs: inputs,
          print: [benchmarking: false, fast_warning: false, configuration: false],
          time: 0,
          reduction_time: 1
        )
      end)

    measured =
      Map.new(result.scenarios, fn scenario ->
        {scenario.input_name, scenario.reductions_data.statistics.maximum}
      end)

    over_budget = for {input, budget} <- budgets, measured[input] > budget, do: input

    assert over_budget == [],
           "over budget: #{inspect(over_budget)}\nmeasured: #{inspect(measured)}\nbudgets:  #{inspect(budgets)}"
  end
end

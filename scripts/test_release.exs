Mix.install([:http_cookie, :req, :tesla], force: true)

# Testing with direct API
url = URI.parse("https://httpbin.org/cookies/set?name=value")

# create a cookie jar
jar = HttpCookie.Jar.new()

IO.puts("\n--- Testing parsing and formatting ---")

# when a response is received, save any cookies that might have been returned
received_headers = [{"Set-Cookie", "name=value; Path=/"}]
jar = HttpCookie.Jar.put_cookies_from_headers(jar, url, received_headers)

# before making requests, prepare the cookie header
{:ok, cookie_header_value, _jar} = HttpCookie.Jar.get_cookie_header_value(jar, url)
IO.puts("Cookie header: #{cookie_header_value}")

IO.puts("\n--- Testing with Req ---")
empty_jar = HttpCookie.Jar.new()

req =
  Req.new(base_url: "https://httpbin.org")
  |> HttpCookie.ReqPlugin.attach()

# Make first request - should set a cookie
response1 = Req.get!(req, url: "/cookies/set?req1=value1", cookie_jar: empty_jar)
IO.puts("Request 1 cookies received: #{inspect(response1.body["cookies"])}")
updated_jar = response1.private.cookie_jar

# Make second request - should send the cookie we received
response2 = Req.get!(req, url: "/cookies", cookie_jar: updated_jar)
IO.puts("Request 2 cookies sent: #{inspect(response2.body["cookies"])}")

IO.puts("\n--- Testing with Tesla ---")
{:ok, server_pid} = HttpCookie.Jar.Server.start_link()

tesla =
  Tesla.client([
    Tesla.Middleware.FollowRedirects,
    {HttpCookie.TeslaMiddleware, jar_server: server_pid},
    Tesla.Middleware.JSON
  ])

# Make first request - should set a cookie
response3 = Tesla.get!(tesla, "https://httpbin.org/cookies/set?tesla1=value1")
IO.puts("Request 1 cookies received: #{inspect(response3.body["cookies"])}")

# Make second request - should send the cookie we received
response4 = Tesla.get!(tesla, "https://httpbin.org/cookies")
IO.puts("Request 2 cookies sent: #{inspect(response4.body["cookies"])}")

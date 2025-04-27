if Code.ensure_loaded?(Tesla) do
  defmodule HttpCookie.TeslaMiddleware do
    @moduledoc """
    Tesla middleware to automatically manage cookies using http_cookie.

    Make sure to list the middleware _after_ any redirect handling
    middleware like Tesla.Middleware.FollowRedirects to ensure
    the cookie handling code is called before/after every redirect.

    ## Options

    - `:jar_server` - HttpCookie.Jar.Server instance pid (required)

    ## Examples

        server_pid = HttpCookie.Jar.Server.start_link([])
        client = Tesla.client([{HttpCookie.TeslaMiddleware, jar_server: server_pid}])
    """

    @behaviour Tesla.Middleware

    alias HttpCookie.Jar

    @impl Tesla.Middleware
    def call(env, next, options) do
      jar_server = Keyword.fetch!(options, :jar_server)

      with %Tesla.Env{} = env <- preprocess(env, jar_server) do
        env
        |> Tesla.run(next)
        |> postprocess(jar_server)
      end
    end

    defp preprocess(env, jar_server) do
      if Tesla.get_header(env, "cookie") do
        # cookie header was already set, do nothing
        # to allow manually setting the cookie header
        env
      else
        url = URI.parse(env.url)

        case Jar.Server.get_cookie_header_value(jar_server, url) do
          {:ok, header_value} ->
            Tesla.put_header(env, "cookie", header_value)

          {:error, :no_matching_cookies} ->
            env
        end
      end
    end

    defp postprocess({:ok, env}, jar_server) do
      url = URI.parse(env.url)
      Jar.Server.put_cookies_from_headers(jar_server, url, env.headers)
      {:ok, env}
    end

    defp postprocess({:error, reason}, _jar_server) do
      {:error, reason}
    end
  end
end

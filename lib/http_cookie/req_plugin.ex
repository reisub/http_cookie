if Code.ensure_loaded?(Req) do
  defmodule HttpCookie.ReqPlugin do
    @moduledoc """
    Automatically manages cookies using http_cookie.
    """

    @doc """
    Attaches the plugin to the request pipeline.

    ## Request Options

      * `:cookie_jar` - HttpCookie.Jar struct to use, defaults to `nil`
    """
    @spec attach(Req.Request.t(), opts :: keyword()) :: Req.Request.t()
    def attach(%Req.Request{} = request, options \\ []) do
      request
      |> Req.Request.register_options([:cookie_jar])
      |> Req.Request.merge_options(options)
      |> Req.Request.append_request_steps(add_cookies: &add_cookies/1)
      |> Req.Request.prepend_response_steps(update_cookies: &update_cookies/1)
    end

    defp add_cookies(%{options: %{cookie_jar: cookie_jar}} = request) when cookie_jar != nil do
      {request, original_cookie_header} =
        if Req.Request.get_private(request, :req_redirect_count, 0) == 0 do
          original_header =
            request
            |> Req.Request.get_header("cookie")
            |> List.first()

          request =
            Req.Request.put_private(request, :http_cookie_orig_cookie_header, original_header)

          {request, original_header}
        else
          {request, Req.Request.get_private(request, :http_cookie_orig_cookie_header)}
        end

      case HttpCookie.Jar.get_cookie_header_value(cookie_jar, request.url) do
        {:ok, value, updated_jar} ->
          request = Req.Request.merge_options(request, cookie_jar: updated_jar)

          # only set the cookie header if the user didn't originally set it
          if original_cookie_header do
            request
          else
            Req.Request.put_header(request, "cookie", value)
          end

        {:error, :no_matching_cookies} ->
          request
      end
    end

    defp add_cookies(request), do: request

    defp update_cookies({%{options: %{cookie_jar: cookie_jar}} = request, response})
         when cookie_jar != nil do
      # req doesn't run request steps after a redirect again, but we need that to include any cookies
      # that might have been returned in the redirect response for the next request
      #
      # Wojtek suggested this as a workaround until there is a better solution
      request = %{
        request
        | current_request_steps: request.current_request_steps ++ [:add_cookies]
      }

      headers =
        Enum.flat_map(response.headers, fn {name, vals} ->
          Enum.map(vals, &{name, &1})
        end)

      updated_jar =
        (response.private[:cookie_jar] || cookie_jar)
        |> HttpCookie.Jar.put_cookies_from_headers(request.url, headers)

      request = Req.Request.merge_options(request, cookie_jar: updated_jar)
      response = Req.Response.put_private(response, :cookie_jar, updated_jar)

      {request, response}
    end

    defp update_cookies({request, response}), do: {request, response}
  end
end

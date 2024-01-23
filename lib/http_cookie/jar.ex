defmodule HttpCookie.Jar do
  defstruct [:cookies, :opts]

  alias HttpCookie

  @type t :: %__MODULE__{
          cookies: list(HttpCookie.t()),
          opts: keyword()
        }

  @doc """
  Creates a new empty cookie jar.

  ## Options

  - `:reject_public_suffixes` - controls whether to reject public suffixes to guard against "supercookies", defaults to true
  """
  @spec new() :: %__MODULE__{}
  @spec new(opts :: keyword()) :: %__MODULE__{}
  def new(opts \\ []) do
    %__MODULE__{
      cookies: %{},
      opts: opts
    }
  end

  @doc """
  Processes the response header list for the given request URL.
  Parses set-cookie/set-cookie2 headers and stores valid cookies.
  """
  @spec put_cookies_from_headers(jar :: t(), request_url :: URI.t(), headers :: list()) :: t()
  def put_cookies_from_headers(jar, request_url, headers) do
    cookies =
      headers
      |> Enum.filter(fn {k, _} -> k =~ ~r/^set-cookie2?$/i end)
      |> Enum.flat_map(fn {_, header} ->
        case HttpCookie.from_cookie_string(header, request_url) do
          {:ok, cookie} -> [cookie]
          _ -> []
        end
      end)

    put_cookies(jar, cookies)
  end

  @doc """
  Stores the provided cookies in the jar.
  """
  @spec put_cookies(jar :: %__MODULE__{}, cookies :: list(HttpCookie.t())) :: %__MODULE__{}
  def put_cookies(jar, cookies) do
    Enum.reduce(cookies, jar, fn cookie, jar ->
      put_cookie(jar, cookie)
    end)
  end

  @doc """
  Stores the provided cookie in the jar.
  """
  @spec put_cookie(jar :: %__MODULE__{}, cookie :: HttpCookie.t()) :: %__MODULE__{}
  def put_cookie(jar, cookie) do
    cookie_key = key(cookie)

    cookie =
      case Map.get(jar.cookies, cookie_key) do
        nil ->
          cookie

        old_cookie ->
          # If the user agent receives a new cookie with the same cookie-name,
          # domain-value, and path-value as a cookie that it has already stored,
          # the existing cookie is evicted and replaced with the new cookie.
          %{cookie | creation_time: old_cookie.creation_time}
      end

    update_in(jar.cookies, fn cookies ->
      Map.put(cookies, cookie_key, cookie)
    end)
  end

  @spec get_cookie_header_value(jar :: %__MODULE__{}, request_url :: URI.t()) ::
          {:ok, String.t()} | {:error, :no_matching_cookies}
  def get_cookie_header_value(jar, request_url) do
    cookies =
      jar
      |> get_matching_cookies(request_url)
      |> Enum.map(&HttpCookie.to_header_value/1)

    if Enum.empty?(cookies) do
      {:error, :no_matching_cookies}
    else
      {:ok, Enum.join(cookies, "; ")}
    end
  end

  @doc """
  Gets all the cookies in the store which match the given request URL.
  """
  @spec get_matching_cookies(jar :: %__MODULE__{}, request_url :: URI.t()) :: list(HttpCookie.t())
  def get_matching_cookies(jar, request_url) do
    now = DateTime.utc_now()

    jar.cookies
    |> Map.values()
    |> Enum.filter(fn cookie ->
      !HttpCookie.expired?(cookie, now) and HttpCookie.matches_url?(cookie, request_url)
    end)
    |> sort_cookies()
    |> Enum.map(&HttpCookie.update_last_access_time/1)
  end

  @doc """
  Removes cookies which expired before the provided time from the jar.

  Uses the current time if no time is provided.
  """
  @spec clear_expired_cookies(jar :: %__MODULE__{}) :: %__MODULE__{}
  @spec clear_expired_cookies(jar :: %__MODULE__{}, now :: DateTime.t()) :: %__MODULE__{}
  def clear_expired_cookies(jar, now \\ DateTime.utc_now()) do
    valid_cookies = Map.reject(jar.cookies, fn {_k, c} -> HttpCookie.expired?(c, now) end)
    %{jar | cookies: valid_cookies}
  end

  @doc """
  Removes session cookies from the jar.

  Cookies which don't have an explicit expiry time set are considered session cookies and they expire when a user session ends.
  """
  @spec clear_session_cookies(jar :: %__MODULE__{}) :: %__MODULE__{}
  def clear_session_cookies(jar) do
    persistent_cookies = Map.filter(jar.cookies, fn {_l, c} -> c.persistent? end)
    %{jar | cookies: persistent_cookies}
  end

  # 2.  The user agent SHOULD sort the cookie-list in the following
  #     order:
  #
  #     *  Cookies with longer paths are listed before cookies with
  #        shorter paths.
  #
  #     *  Among cookies that have equal-length path fields, cookies with
  #        earlier creation-times are listed before cookies with later
  #        creation-times.
  defp sort_cookies(cookies) do
    Enum.sort(cookies, fn lhs_cookie, rhs_cookie ->
      lhs_path_size = byte_size(lhs_cookie.path)
      rhs_path_size = byte_size(rhs_cookie.path)

      if lhs_path_size == rhs_path_size do
        DateTime.before?(lhs_cookie.creation_time, rhs_cookie.creation_time)
      else
        lhs_path_size > rhs_path_size
      end
    end)
  end

  defp key(cookie) do
    {cookie.name, cookie.domain, cookie.path}
  end
end

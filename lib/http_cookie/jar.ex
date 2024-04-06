defmodule HttpCookie.Jar do
  @moduledoc """
  HTTP Cookie Jar

  Handles storing cookies from response headers, preparing cookie headers for requests, etc.

  Implemented according to [RFC6265](https://datatracker.ietf.org/doc/html/rfc6265)
  """

  alias HttpCookie

  defstruct [:cookies, :opts]

  @type t :: %__MODULE__{
          cookies: map(),
          opts: keyword()
        }

  defmodule DomainCookies do
    defstruct count: 0,
              cookies: %{}
  end

  @doc """
  Creates a new empty cookie jar.

  ## Options

  - `:max_cookies` - maximum number of cookies stored, positive integer or :infinity, default: 5_000
  - `:max_cookies_per_domain` - maximum number of cookies stored per domain, positive integer or :infinity, default: 100
  - `:cookie_opts` - options passed to HttpCookie
  """
  @spec new() :: %__MODULE__{}
  @spec new(opts :: keyword()) :: %__MODULE__{}
  def new(opts \\ []) do
    validate_opts!(opts)

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
    cookie_opts = Keyword.get(jar.opts, :cookie_opts, [])

    cookies =
      headers
      |> Enum.filter(fn {k, _} -> k =~ ~r/^set-cookie2?$/i end)
      |> Enum.flat_map(fn {_, header} ->
        case HttpCookie.from_cookie_string(header, request_url, cookie_opts) do
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
      put_cookie(jar, cookie, clear_expired: false, apply_limits: false)
    end)
    |> clear_expired_cookies()
    |> apply_limits()
  end

  @doc """
  Stores the provided cookie in the jar.
  """
  @spec put_cookie(jar :: %__MODULE__{}, cookie :: HttpCookie.t()) :: %__MODULE__{}
  @spec put_cookie(jar :: %__MODULE__{}, cookie :: HttpCookie.t(), opts :: list()) ::
          %__MODULE__{}
  def put_cookie(jar, cookie, opts \\ []) do
    clear_expired? = Keyword.get(opts, :clear_expired, true)
    apply_limits? = Keyword.get(opts, :apply_limits, true)

    jar =
      Map.update!(jar, :cookies, fn cookies ->
        Map.put_new(cookies, cookie.domain, %DomainCookies{})
      end)

    jar
    |> put_or_update_cookie(cookie)
    |> then(fn jar ->
      if clear_expired? do
        clear_expired_cookies(jar)
      else
        jar
      end
    end)
    |> then(fn jar ->
      if apply_limits? do
        apply_limits(jar)
      else
        jar
      end
    end)
  end

  @doc """
  Formats the cookie for sending in a request header for the provided URL.
  """
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

    jar
    |> all_cookies()
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
    updated_cookies =
      jar.cookies
      |> Map.new(fn {domain, %{cookies: domain_cookies}} ->
        %{
          result: result,
          kept: kept
        } = filter_with_count(domain_cookies, fn {_k, c} -> !HttpCookie.expired?(c, now) end)

        {domain, %{count: kept, cookies: Map.new(result)}}
      end)

    %{jar | cookies: updated_cookies}
  end

  @doc """
  Removes session cookies from the jar.

  Cookies which don't have an explicit expiry time set are considered session cookies and they expire when a user session ends.
  """
  @spec clear_session_cookies(jar :: %__MODULE__{}) :: %__MODULE__{}
  def clear_session_cookies(jar) do
    updated_cookies =
      jar.cookies
      |> Map.new(fn {domain, %{cookies: domain_cookies}} ->
        %{
          result: result,
          kept: kept
        } = filter_with_count(domain_cookies, fn {_k, c} -> c.persistent? end)

        {domain, %{count: kept, cookies: Map.new(result)}}
      end)

    %{jar | cookies: updated_cookies}
  end

  defp put_or_update_cookie(jar, cookie) do
    cookie_access_path = cookie_access_path(cookie)

    case get_in(jar, cookie_access_path) do
      nil ->
        count_access_path = count_access_path(cookie)
        domain_cookie_count = get_in(jar, count_access_path)

        jar
        |> put_in(cookie_access_path, cookie)
        |> put_in(count_access_path, domain_cookie_count + 1)

      old_cookie ->
        # If the user agent receives a new cookie with the same cookie-name,
        # domain-value, and path-value as a cookie that it has already stored,
        # the existing cookie is evicted and replaced with the new cookie.
        put_in(jar, cookie_access_path, %{cookie | creation_time: old_cookie.creation_time})
    end
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

  # At any time, the user agent MAY "remove excess cookies" from the
  # cookie store if the number of cookies sharing a domain field exceeds
  # some implementation-defined upper bound (such as 50 cookies).
  #
  # At any time, the user agent MAY "remove excess cookies" from the
  # cookie store if the cookie store exceeds some predetermined upper
  # bound (such as 3000 cookies).
  #
  # When the user agent removes excess cookies from the cookie store, the
  # user agent MUST evict cookies in the following priority order:
  #
  # 1.  Expired cookies.
  #
  # 2.  Cookies that share a domain field with more than a predetermined
  #     number of other cookies.
  #
  # 3.  All cookies.
  #
  # If two cookies have the same removal priority, the user agent MUST
  # evict the cookie with the earliest last-access date first.
  defp apply_limits(%{opts: opts} = jar) do
    max_cookies_per_domain = Keyword.get(opts, :max_cookies_per_domain, 100)
    max_cookies = Keyword.get(opts, :max_cookies, 5_000)

    jar
    |> apply_per_domain_limit(max_cookies_per_domain)
    |> apply_limit(max_cookies)
  end

  defp apply_per_domain_limit(jar, :infinity), do: jar

  defp apply_per_domain_limit(jar, limit) do
    Map.update!(jar, :cookies, fn cookies ->
      Map.new(cookies, fn {domain, %{count: count, cookies: domain_cookies}} ->
        if count > limit do
          updated =
            domain_cookies
            |> Enum.sort_by(fn {_k, c} -> c.last_access_time end, {:desc, DateTime})
            |> Enum.take(limit)

          {domain, %{count: limit, cookies: Map.new(updated)}}
        else
          {domain, %{count: count, cookies: domain_cookies}}
        end
      end)
    end)
  end

  defp apply_limit(jar, :infinity), do: jar

  defp apply_limit(jar, limit) do
    Map.update!(jar, :cookies, fn cookies ->
      total_count =
        cookies
        |> Enum.map(fn {_d, %{count: c}} -> c end)
        |> Enum.sum()

      if total_count > limit do
        updated_cookies =
          jar.cookies
          |> Map.values()
          |> Enum.flat_map(&Map.to_list(&1.cookies))
          |> Enum.sort_by(fn {_k, c} -> c.last_access_time end, {:desc, DateTime})
          |> Enum.take(limit)
          |> Enum.group_by(fn {_k, c} -> c.domain end)
          |> Map.new(fn {domain, cookie_list} ->
            {
              domain,
              %{
                count: length(cookie_list),
                cookies: Map.new(cookie_list)
              }
            }
          end)

        updated_cookies
      else
        cookies
      end
    end)
  end

  defp all_cookies(jar) do
    jar.cookies
    |> Map.values()
    |> Enum.flat_map(&Map.values(&1.cookies))
  end

  defp count_access_path(cookie) do
    [Access.key(:cookies), cookie.domain, Access.key(:count)]
  end

  defp cookie_access_path(cookie) do
    [Access.key(:cookies), cookie.domain, Access.key(:cookies), {cookie.name, cookie.path}]
  end

  defp filter_with_count(list, fun) do
    list
    |> Enum.reverse()
    |> Enum.reduce(%{result: [], kept: 0, discarded: 0}, fn item, acc ->
      if fun.(item) do
        %{acc | result: [item | acc.result], kept: acc.kept + 1}
      else
        %{acc | discarded: acc.discarded + 1}
      end
    end)
  end

  defp validate_opts!(_opts) do
    # TODO raise if any of the options is invalid!
  end
end

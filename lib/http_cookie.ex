defmodule HttpCookie do
  @moduledoc """
  HTTP Cookie struct with parsing and related logic.

  Implemented according to [RFC6265](https://datatracker.ietf.org/doc/html/rfc6265)
  """

  import __MODULE__.Parser, only: [latest_expiry_time: 0]
  import __MODULE__.Util, only: [pretty_module: 1]

  alias __MODULE__.{Parser, URL}

  @derive {Inspect, except: [:value]}
  @enforce_keys [:name, :value]
  defstruct [
    :name,
    :value,
    :domain,
    :path,
    :creation_time,
    :expiry_time,
    :last_access_time,
    :persistent?,
    :host_only?,
    :secure_only?,
    :http_only?
  ]

  @type t :: %__MODULE__{
          name: binary(),
          value: binary(),
          domain: binary(),
          path: binary(),
          creation_time: DateTime.t(),
          expiry_time: DateTime.t(),
          last_access_time: DateTime.t(),
          persistent?: boolean(),
          host_only?: boolean(),
          secure_only?: boolean(),
          http_only?: boolean()
        }

  @doc """
  Creates an HttpCookie from a `Set-Cookie` header value.

  ## Options

  - `:max_cookie_size` - maximum size of cookie string in bytes, positive integer or :infinity, default: 8_192
  """
  @spec from_cookie_string(str :: String.t(), request_url :: URI.t()) ::
          {:ok, t()} | {:error, atom()}
  @spec from_cookie_string(str :: String.t(), request_url :: URI.t(), opts :: keyword()) ::
          {:ok, t()} | {:error, atom()}
  def from_cookie_string(str, %URI{} = request_url, opts \\ []) do
    validate_opts!(opts)
    max_size = Keyword.get(opts, :max_cookie_size, 8_192)

    with :ok <- check_size(str, max_size),
         {:ok, request_domain} <- canonicalize_request_host(request_url),
         :ok <- check_ctl(str),
         {name, value, attributes} = Parser.parse_cookie_string(str, request_url),
         attributes = Enum.reverse(attributes),
         {:ok, cookie} <- new_cookie(name, value),
         cookie = set_expiry_time(cookie, attributes),
         cookie = set_domain(cookie, attributes),
         {:ok, cookie} <- check_public_suffix(cookie, request_domain),
         {:ok, cookie} <- check_domain(cookie, request_domain),
         cookie = set_path(cookie, attributes, request_url),
         cookie = set_secure_only(cookie, attributes),
         :ok <- check_secure_origin(cookie, request_url),
         :ok <- check_prefix(cookie, attributes) do
      {:ok, set_http_only(cookie, attributes)}
    end
  end

  @doc """
  Formats the cookie for sending in a "Cookie" header.
  """
  @spec to_header_value(cookie :: t()) :: String.t()
  def to_header_value(cookie) do
    "#{cookie.name}=#{cookie.value}"
  end

  @doc """
  Checks if the cookie has expired.

  Uses the current time if no time is provided.
  """
  @spec expired?(cookie :: t()) :: boolean()
  @spec expired?(cookie :: t(), now :: DateTime.t()) :: boolean()
  def expired?(cookie, now \\ DateTime.utc_now()) do
    DateTime.after?(now, cookie.expiry_time)
  end

  # 5.4.  The Cookie Header
  # [...]
  #    1.  Let cookie-list be the set of cookies from the cookie store that
  #        meets all of the following requirements:
  #
  #        *  Either:
  #
  #              The cookie's host-only-flag is true and the canonicalized
  #              request-host is identical to the cookie's domain.
  #
  #           Or:
  #
  #              The cookie's host-only-flag is false and the canonicalized
  #              request-host domain-matches the cookie's domain.
  #
  #        *  The request-uri's path path-matches the cookie's path.
  #
  #        *  If the cookie's secure-only-flag is true, then the request-
  #           uri's scheme must denote a "secure" protocol (as defined by
  #           the user agent).
  #
  #              NOTE: The notion of a "secure" protocol is not defined by
  #              this document.  Typically, user agents consider a protocol
  #              secure if the protocol makes use of transport-layer
  #
  #              security, such as SSL or TLS.  For example, most user
  #              agents consider "https" to be a scheme that denotes a
  #              secure protocol.
  #
  #        *  If the cookie's http-only-flag is true, then exclude the
  #           cookie if the cookie-string is being generated for a "non-
  #           HTTP" API (as defined by the user agent).
  @doc """
  Checks if the cookie matches the provided request url.

  The check is done as specified in [RFC 6265](https://datatracker.ietf.org/doc/html/rfc6265#section-5.4).
  """
  @spec matches_url?(cookie :: t(), request_url :: URI.t()) :: boolean()
  def matches_url?(cookie, %URI{} = request_url) do
    case request_matcher(request_url) do
      nil -> false
      matcher -> matches_request?(cookie, matcher)
    end
  end

  @typedoc false
  @type request_matcher :: {domain :: String.t(), path :: String.t(), secure? :: boolean()}

  # Canonicalizes the request URL once, so matching many cookies against it
  # doesn't redo that work for each cookie. Returns nil if the host can't be
  # canonicalized, in which case no cookie matches.
  @doc false
  @spec request_matcher(request_url :: URI.t()) :: request_matcher() | nil
  def request_matcher(%URI{} = request_url) do
    case URL.canonicalize_domain(request_url.host) do
      nil -> nil
      domain -> {domain, URL.normalize_path(request_url.path), URL.secure?(request_url)}
    end
  end

  @doc false
  @spec matches_request?(cookie :: t(), request_matcher()) :: boolean()
  def matches_request?(cookie, {request_domain, request_path, secure?}) do
    matches_domain?(cookie, request_domain) and
      URL.path_match?(request_path, cookie.path) and
      (!cookie.secure_only? or secure?)
  end

  @doc """
  Updates the cookie last access time.

  Uses the current time if no time is provided.
  """
  @spec update_last_access_time(cookie :: t()) :: t()
  @spec update_last_access_time(cookie :: t(), DateTime.t()) :: t()
  def update_last_access_time(%__MODULE__{} = cookie, now \\ DateTime.utc_now()) do
    %{cookie | last_access_time: now}
  end

  @doc false
  @spec validate_opts!(opts :: keyword()) :: :ok
  def validate_opts!(opts) when is_list(opts) do
    Enum.each(opts, fn {k, v} -> validate_opt!(k, v) end)
  end

  defp validate_opt!(:max_cookie_size, :infinity), do: :ok

  defp validate_opt!(:max_cookie_size, cnt) when is_integer(cnt) and cnt >= 0, do: :ok

  defp validate_opt!(:max_cookie_size = k, val) do
    raise ArgumentError,
          "[#{pretty_module(__MODULE__)}] invalid value for :#{k} option: #{inspect(val)}\n\n expected :infinity or an integer >= 0"
  end

  defp validate_opt!(k, _) do
    raise ArgumentError, "[#{pretty_module(__MODULE__)}] invalid option #{inspect(k)}"
  end

  defp matches_domain?(%{domain: domain}, domain), do: true
  defp matches_domain?(%{host_only?: true}, _domain), do: false

  defp matches_domain?(%{host_only?: false} = cookie, domain) do
    URL.domain_match?(domain, cookie.domain)
  end

  defp new_cookie("", _value), do: {:error, :cookie_missing_name}
  defp new_cookie(_name, nil), do: {:error, :cookie_missing_value}

  # 2.   Create a new cookie with name cookie-name, value cookie-value.
  #      Set the creation-time and the last-access-time to the current
  #      date and time.
  defp new_cookie(name, value) do
    now = DateTime.utc_now()

    cookie = %__MODULE__{
      name: name,
      value: value,
      creation_time: now,
      last_access_time: now
    }

    {:ok, cookie}
  end

  # 3.   If the cookie-attribute-list contains an attribute with an
  #      attribute-name of "Max-Age":
  #
  #         Set the cookie's persistent-flag to true.
  #
  #         Set the cookie's expiry-time to attribute-value of the last
  #         attribute in the cookie-attribute-list with an attribute-name
  #         of "Max-Age".
  #
  #      Otherwise, if the cookie-attribute-list contains an attribute
  #      with an attribute-name of "Expires" (and does not contain an
  #      attribute with an attribute-name of "Max-Age"):
  #
  #         Set the cookie's persistent-flag to true.
  #
  #         Set the cookie's expiry-time to attribute-value of the last
  #         attribute in the cookie-attribute-list with an attribute-name
  #         of "Expires".
  #
  #      Otherwise:
  #
  #         Set the cookie's persistent-flag to false.
  #
  #         Set the cookie's expiry-time to the latest representable
  #         date.
  defp set_expiry_time(cookie, attributes) do
    with nil <- List.keyfind(attributes, "Max-Age", 0),
         nil <- List.keyfind(attributes, "Expires", 0) do
      %{cookie | expiry_time: latest_expiry_time(), persistent?: false}
    else
      {"Max-Age", expiry_time} ->
        %{cookie | expiry_time: expiry_time, persistent?: true}

      {"Expires", expiry_time} ->
        %{cookie | expiry_time: expiry_time, persistent?: true}
    end
  end

  # 4.   If the cookie-attribute-list contains an attribute with an
  #      attribute-name of "Domain":
  #
  #         Let the domain-attribute be the attribute-value of the last
  #         attribute in the cookie-attribute-list with an attribute-name
  #         of "Domain".
  #
  #      Otherwise:
  #
  #         Let the domain-attribute be the empty string.
  defp set_domain(cookie, attributes) do
    case List.keyfind(attributes, "Domain", 0) do
      {"Domain", domain} -> %{cookie | domain: domain}
      nil -> %{cookie | domain: ""}
    end
  end

  # 5.   If the user agent is configured to reject "public suffixes" and
  #      the domain-attribute is a public suffix:
  #
  #         If the domain-attribute is identical to the canonicalized
  #         request-host:
  #
  #            Let the domain-attribute be the empty string.
  #
  #         Otherwise:
  #
  #            Ignore the cookie entirely and abort these steps.
  defp check_public_suffix(cookie, request_domain) do
    public_suffix? = URL.public_suffix?(cookie.domain)

    cond do
      public_suffix? and cookie.domain == request_domain ->
        {:ok, %{cookie | domain: ""}}

      public_suffix? ->
        {:error, :cookie_domain_public_suffix}

      true ->
        {:ok, cookie}
    end
  end

  # 6.   If the domain-attribute is non-empty:
  #
  #         If the canonicalized request-host does not domain-match the
  #         domain-attribute:
  #
  #            Ignore the cookie entirely and abort these steps.
  #
  #         Otherwise:
  #
  #            Set the cookie's host-only-flag to false.
  #
  #            Set the cookie's domain to the domain-attribute.
  #
  #      Otherwise:
  #
  #         Set the cookie's host-only-flag to true.
  #
  #         Set the cookie's domain to the canonicalized request-host.
  defp check_domain(%{domain: ""} = cookie, request_domain) do
    cookie = %{cookie | domain: request_domain, host_only?: true}
    {:ok, cookie}
  end

  defp check_domain(%{domain: cookie_domain} = cookie, request_domain) do
    if URL.domain_match?(request_domain, cookie_domain) do
      cookie = %{cookie | host_only?: false}
      {:ok, cookie}
    else
      {:error, :cookie_domain_mismatch}
    end
  end

  # 7.   If the cookie-attribute-list contains an attribute with an
  #      attribute-name of "Path", set the cookie's path to attribute-
  #      value of the last attribute in the cookie-attribute-list with an
  #      attribute-name of "Path".  Otherwise, set the cookie's path to
  #      the default-path of the request-uri.
  defp set_path(cookie, attributes, request_url) do
    case List.keyfind(attributes, "Path", 0) do
      {"Path", domain} -> %{cookie | path: domain}
      nil -> %{cookie | path: URL.default_path(request_url)}
    end
  end

  # 8.   If the cookie-attribute-list contains an attribute with an
  #      attribute-name of "Secure", set the cookie's secure-only-flag to
  #      true.  Otherwise, set the cookie's secure-only-flag to false.
  defp set_secure_only(cookie, attributes) do
    case List.keyfind(attributes, "Secure", 0) do
      {"Secure", _} -> %{cookie | secure_only?: true}
      nil -> %{cookie | secure_only?: false}
    end
  end

  # RFC6265bis: if the secure-only-flag is true and the request-uri's scheme
  # does not denote a secure protocol, ignore the cookie entirely.
  defp check_secure_origin(cookie, request_url) do
    if cookie.secure_only? and not URL.secure?(request_url),
      do: {:error, :cookie_secure_from_insecure_origin},
      else: :ok
  end

  # RFC6265bis: "__Secure-" cookies must be Secure and set from a secure origin,
  # "__Host-" cookies additionally must have no Domain attribute and Path=/.
  # check_secure_origin/2 runs first and already rejects Secure cookies from
  # insecure origins, so the Secure flag is all that's left to check here.
  defp check_prefix(%{secure_only?: secure?} = cookie, attributes) do
    name = String.downcase(cookie.name)

    host_ok? =
      secure? and List.keyfind(attributes, "Domain", 0) == nil and
        List.keyfind(attributes, "Path", 0) == {"Path", "/"}

    cond do
      String.starts_with?(name, "__secure-") and not secure? -> {:error, :cookie_invalid_prefix}
      String.starts_with?(name, "__host-") and not host_ok? -> {:error, :cookie_invalid_prefix}
      true -> :ok
    end
  end

  # 9.   If the cookie-attribute-list contains an attribute with an
  #      attribute-name of "HttpOnly", set the cookie's http-only-flag to
  #      true.  Otherwise, set the cookie's http-only-flag to false.
  defp set_http_only(cookie, attributes) do
    case List.keyfind(attributes, "HttpOnly", 0) do
      {"HttpOnly", _} -> %{cookie | http_only?: true}
      nil -> %{cookie | http_only?: false}
    end
  end

  # RFC6265bis: if the set-cookie-string contains a %x00-08 / %x0A-1F / %x7F
  # character (CTL characters excluding HTAB), ignore it entirely.
  defp check_ctl(str) do
    if str =~ ~r/[\x00-\x08\x0A-\x1F\x7F]/, do: {:error, :cookie_invalid_characters}, else: :ok
  end

  defp canonicalize_request_host(request_url) do
    case URL.canonicalize_domain(request_url.host) do
      nil -> {:error, :cookie_invalid_request_host}
      request_domain -> {:ok, request_domain}
    end
  end

  defp check_size(_str, :infinity), do: :ok
  defp check_size(str, max_size) when byte_size(str) <= max_size, do: :ok
  defp check_size(_str, _max_size), do: {:error, :cookie_exceeds_max_size}
end

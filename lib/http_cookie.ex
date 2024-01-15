defmodule HttpCookie do
  @moduledoc """
  HTTP Cookie struct with parsing and related logic.

  Implemented according to [RFC6265](https://datatracker.ietf.org/doc/html/rfc6265)
  """

  alias __MODULE__.{Parser, URL}
  import __MODULE__.Parser, only: [latest_expiry_time: 0]

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

  - `:reject_public_suffixes` - controls whether to reject public suffixes to guard against "supercookies", defaults to true
  """
  @spec from_cookie_string(str :: String.t(), request_url :: URI.t()) ::
          {:ok, t()} | {:error, atom()}
  def from_cookie_string(str, %URI{} = request_url, opts \\ []) do
    {name, value, attributes} = Parser.parse_cookie_string(str, request_url)
    attributes = Enum.reverse(attributes)

    with {:ok, cookie} <- new_cookie(name, value),
         cookie = set_expiry_time(cookie, attributes),
         cookie = set_domain(cookie, attributes),
         {:ok, cookie} <- check_public_suffix(cookie, request_url, opts),
         {:ok, cookie} <- check_domain(cookie, request_url) do
      cookie =
        cookie
        |> set_path(attributes, request_url)
        |> set_secure_only(attributes)
        |> set_http_only(attributes)

      {:ok, cookie}
    end
  end

  @doc """
  Formats the cookie for sending in a "Cookie" header.
  """
  def to_header_value(cookie) do
    "#{cookie.name}=#{cookie.value}"
  end

  @doc """
  Checks if a cookie has expired.

  Uses the current time if no time is provided.
  """
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
  def matches_url?(cookie, %URI{} = request_url) do
    request_domain = URL.canonicalize_domain(request_url.host)
    request_path = URL.normalize_path(request_url.path)

    matches_domain?(cookie, request_domain) and
      URL.path_match?(request_path, cookie.path) and
      (!cookie.secure_only? or request_url.scheme == "https")
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

    cookie = %HttpCookie{
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
  defp check_public_suffix(cookie, request_url, opts) do
    if Keyword.get(opts, :reject_public_suffixes, true) do
      request_domain = URL.canonicalize_domain(request_url.host)
      public_suffix? = URL.public_suffix?(cookie.domain)

      cond do
        public_suffix? and cookie.domain == request_domain ->
          {:ok, %{cookie | domain: ""}}

        public_suffix? ->
          {:error, :cookie_domain_public_suffix}

        true ->
          {:ok, cookie}
      end
    else
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
  defp check_domain(%{domain: ""} = cookie, request_url) do
    cookie = %{cookie | domain: request_url.host, host_only?: true}
    {:ok, cookie}
  end

  defp check_domain(%{domain: cookie_domain} = cookie, request_url) do
    request_domain = URL.canonicalize_domain(request_url.host)

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

  # 9.   If the cookie-attribute-list contains an attribute with an
  #      attribute-name of "HttpOnly", set the cookie's http-only-flag to
  #      true.  Otherwise, set the cookie's http-only-flag to false.
  defp set_http_only(cookie, attributes) do
    case List.keyfind(attributes, "HttpOnly", 0) do
      {"HttpOnly", _} -> %{cookie | http_only?: true}
      nil -> %{cookie | http_only?: false}
    end
  end
end

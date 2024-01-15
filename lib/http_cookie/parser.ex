defmodule HttpCookie.Parser do
  alias HttpCookie.{DateParser, URL}

  @moduledoc false

  @spec earliest_expiry_time() :: DateTime.t()
  def earliest_expiry_time, do: ~U[1601-01-01 00:00:00Z]

  @spec latest_expiry_time() :: DateTime.t()
  def latest_expiry_time, do: ~U[9999-12-31T23:59:59Z]

  # 5.2.  The Set-Cookie Header
  # [...]
  # A user agent MUST use an algorithm equivalent to the following
  # algorithm to parse a "set-cookie-string":
  #
  # 1.  If the set-cookie-string contains a %x3B (";") character:
  #
  #        The name-value-pair string consists of the characters up to,
  #        but not including, the first %x3B (";"), and the unparsed-
  #        attributes consist of the remainder of the set-cookie-string
  #        (including the %x3B (";") in question).
  #
  #     Otherwise:
  #
  #        The name-value-pair string consists of all the characters
  #        contained in the set-cookie-string, and the unparsed-
  #        attributes is the empty string.
  #
  # 2.  If the name-value-pair string lacks a %x3D ("=") character,
  #     ignore the set-cookie-string entirely.
  #
  # 3.  The (possibly empty) name string consists of the characters up
  #     to, but not including, the first %x3D ("=") character, and the
  #     (possibly empty) value string consists of the characters after
  #     the first %x3D ("=") character.
  #
  # 4.  Remove any leading or trailing WSP characters from the name
  #     string and the value string.
  #
  # 5.  If the name string is empty, ignore the set-cookie-string
  #     entirely.
  #
  # 6.  The cookie-name is the name string, and the cookie-value is the
  #     value string.
  def parse_cookie_string(str, request_url) do
    case String.split(str, ";", parts: 2) do
      [name_value_pair] ->
        {name, value} = parse_key_value_pair(name_value_pair)
        {name, value, []}

      [name_value_pair, unparsed_attributes] ->
        {name, value} = parse_key_value_pair(name_value_pair)
        attributes = parse_attributes(unparsed_attributes, request_url)
        {name, value, attributes}
    end
  end

  defp parse_key_value_pair(str) do
    case String.split(str, "=", parts: 2) do
      [name] -> {trim_wsp(name), nil}
      [name, value] -> {trim_wsp(name), trim_wsp(value)}
    end
  end

  # 1.  If the unparsed-attributes string is empty, skip the rest of
  #     these steps.
  #
  # 2.  Discard the first character of the unparsed-attributes (which
  #     will be a %x3B (";") character).
  #
  # 3.  If the remaining unparsed-attributes contains a %x3B (";")
  #     character:
  #
  #        Consume the characters of the unparsed-attributes up to, but
  #        not including, the first %x3B (";") character.
  #
  #     Otherwise:
  #
  #        Consume the remainder of the unparsed-attributes.
  #
  #     Let the cookie-av string be the characters consumed in this step.
  #
  # 4.  If the cookie-av string contains a %x3D ("=") character:
  #
  #        The (possibly empty) attribute-name string consists of the
  #        characters up to, but not including, the first %x3D ("=")
  #        character, and the (possibly empty) attribute-value string
  #        consists of the characters after the first %x3D ("=")
  #        character.
  #
  #     Otherwise:
  #
  #        The attribute-name string consists of the entire cookie-av
  #        string, and the attribute-value string is empty.
  #
  # 5.  Remove any leading or trailing WSP characters from the attribute-
  #     name string and the attribute-value string.
  #
  # 6.  Process the attribute-name and attribute-value according to the
  #     requirements in the following subsections.  (Notice that
  #     attributes with unrecognized attribute-names are ignored.)
  #
  # 7.  Return to Step 1 of this algorithm.
  defp parse_attributes(unparsed_attributes, request_url) do
    unparsed_attributes
    |> String.split(";")
    |> Enum.map(&parse_key_value_pair/1)
    |> Enum.map(fn {name, val} ->
      name = String.downcase(name)
      parse_attribute({name, val}, request_url)
    end)
    |> Enum.reject(&is_nil/1)
  end

  # 5.2.1.  The Expires Attribute
  #
  #    If the attribute-name case-insensitively matches the string
  #    "Expires", the user agent MUST process the cookie-av as follows.
  #
  #    Let the expiry-time be the result of parsing the attribute-value as
  #    cookie-date (see Section 5.1.1).
  #
  #    If the attribute-value failed to parse as a cookie date, ignore the
  #    cookie-av.
  #
  #    If the expiry-time is later than the last date the user agent can
  #    represent, the user agent MAY replace the expiry-time with the last
  #    representable date.
  #
  #    If the expiry-time is earlier than the earliest date the user agent
  #    can represent, the user agent MAY replace the expiry-time with the
  #    earliest representable date.
  #
  #    Append an attribute to the cookie-attribute-list with an attribute-
  #    name of Expires and an attribute-value of expiry-time.
  defp parse_attribute({"expires", val}, _request_url) do
    case DateParser.parse(val) do
      {:ok, dt} ->
        cond do
          DateTime.after?(dt, latest_expiry_time()) ->
            {"Expires", latest_expiry_time()}

          DateTime.before?(dt, earliest_expiry_time()) ->
            {"Expires", earliest_expiry_time()}

          true ->
            {"Expires", dt}
        end

      {:error, _} ->
        nil
    end
  end

  # 5.2.2.  The Max-Age Attribute
  #
  #    If the attribute-name case-insensitively matches the string "Max-
  #    Age", the user agent MUST process the cookie-av as follows.
  #
  #    If the first character of the attribute-value is not a DIGIT or a "-"
  #    character, ignore the cookie-av.
  #
  #    If the remainder of attribute-value contains a non-DIGIT character,
  #    ignore the cookie-av.
  #
  #    Let delta-seconds be the attribute-value converted to an integer.
  #
  #    If delta-seconds is less than or equal to zero (0), let expiry-time
  #    be the earliest representable date and time.  Otherwise, let the
  #    expiry-time be the current date and time plus delta-seconds seconds.
  #
  #    Append an attribute to the cookie-attribute-list with an attribute-
  #    name of Max-Age and an attribute-value of expiry-time.
  defp parse_attribute({"max-age", val}, _request_url) do
    case Integer.parse(val) do
      {seconds, ""} when seconds <= 0 ->
        {"Max-Age", earliest_expiry_time()}

      {seconds, ""} when seconds > 0 ->
        expiry_time =
          DateTime.utc_now()
          |> DateTime.add(seconds, :second)

        {"Max-Age", expiry_time}

      _ ->
        # invalid values are ignored
        nil
    end
  end

  # 5.2.3.  The Domain Attribute
  #
  #    If the attribute-name case-insensitively matches the string "Domain",
  #    the user agent MUST process the cookie-av as follows.
  #
  #    If the attribute-value is empty, the behavior is undefined.  However,
  #    the user agent SHOULD ignore the cookie-av entirely.
  #
  #    If the first character of the attribute-value string is %x2E ("."):
  #
  #       Let cookie-domain be the attribute-value without the leading %x2E
  #       (".") character.
  #
  #    Otherwise:
  #
  #       Let cookie-domain be the entire attribute-value.
  #
  #    Convert the cookie-domain to lower case.
  #
  #    Append an attribute to the cookie-attribute-list with an attribute-
  #    name of Domain and an attribute-value of cookie-domain.
  defp parse_attribute({"domain", ""}, _request_url), do: nil

  defp parse_attribute({"domain", val}, _request_url) do
    domain =
      case val do
        "." <> rest -> rest
        other -> other
      end

    {"Domain", String.downcase(domain)}
  end

  # 5.2.4.  The Path Attribute
  #
  #    If the attribute-name case-insensitively matches the string "Path",
  #    the user agent MUST process the cookie-av as follows.
  #
  #    If the attribute-value is empty or if the first character of the
  #    attribute-value is not %x2F ("/"):
  #
  #       Let cookie-path be the default-path.
  #
  #    Otherwise:
  #
  #       Let cookie-path be the attribute-value.
  #
  #    Append an attribute to the cookie-attribute-list with an attribute-
  #    name of Path and an attribute-value of cookie-path.
  defp parse_attribute({"path", "/" <> path}, _request_url) do
    {"Path", "/#{path}"}
  end

  defp parse_attribute({"path", _val}, request_url) do
    {"Path", URL.default_path(request_url)}
  end

  # 5.2.5.  The Secure Attribute
  #
  #    If the attribute-name case-insensitively matches the string "Secure",
  #    the user agent MUST append an attribute to the cookie-attribute-list
  #    with an attribute-name of Secure and an empty attribute-value.
  defp parse_attribute({"secure", _val}, _request_url) do
    {"Secure", ""}
  end

  # 5.2.6.  The HttpOnly Attribute
  #
  #    If the attribute-name case-insensitively matches the string
  #    "HttpOnly", the user agent MUST append an attribute to the cookie-
  #    attribute-list with an attribute-name of HttpOnly and an empty
  #    attribute-value.
  defp parse_attribute({"httponly", _val}, _request_url) do
    {"HttpOnly", ""}
  end

  # attributes with unrecognized attribute-names are ignored
  defp parse_attribute({_name, _val}, _request_url), do: nil

  defp trim_wsp(str) do
    # RFC 5234, appendix-B.1 defines whitespace (WSP) as
    # either a space (SP) or a horizontal tab (HTAB)
    String.replace(str, ~r/^[ \t]*(.*?)[ \t]*$/, "\\g{1}")
  end
end

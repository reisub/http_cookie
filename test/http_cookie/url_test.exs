defmodule HttpCookie.URLTest do
  use ExUnit.Case, async: true

  import HttpCookie.URL

  test "canonicalize_domain/1" do
    assert canonicalize_domain("example.org") == "example.org"
    assert canonicalize_domain("EXAMPLE.ORG") == "example.org"
    assert canonicalize_domain("ö.example.org") == "xn--nda.example.org"
    assert canonicalize_domain("My_Service") == "my_service"
    assert canonicalize_domain("::1") == "::1"
    assert canonicalize_domain("127.0.0.1") == "127.0.0.1"
  end

  test "normalize_path/1" do
    assert normalize_path(nil) == "/"
    assert normalize_path("") == "/"
    assert normalize_path("/") == "/"
    assert normalize_path("/path") == "/path"
    assert normalize_path("/some/path") == "/some/path"
    assert normalize_path("path") == "path"
    assert normalize_path("some/path") == "some/path"
  end

  test "default_path/1" do
    assert URI.parse("https://example.org") |> default_path() == "/"
    assert URI.parse("https://example.org/") |> default_path() == "/"
    assert URI.parse("https://example.org/some") |> default_path() == "/"
    assert URI.parse("https://example.org/some/") |> default_path() == "/some"

    assert URI.parse("https://example.org/some/path") |> default_path() ==
             "/some"

    assert URI.parse("https://example.org/some/path/") |> default_path() ==
             "/some/path"
  end

  test "path_match?/1" do
    assert path_match?("/", "/")
    assert path_match?("/some", "/")
    assert path_match?("/some", "/some")
    assert path_match?("/some/path", "/some")
    assert path_match?("/some/path/here", "/some")
    assert path_match?("/some/", "/some/")
    assert path_match?("/some/path", "/some/")

    refute path_match?("/sometimes", "/some")
    refute path_match?("/sometimes", "/some/")
    refute path_match?("/some", "/some/")
  end

  test "domain_match?/1" do
    assert domain_match?("some.example.org", "some.example.org")
    assert domain_match?("some.example.org", "example.org")
    assert domain_match?(".example.org", "example.org")

    refute domain_match?("some,example.org", "example.org")
    refute domain_match?("someexample.org", "example.org")
    refute domain_match?("com", "example.org")
  end

  test "secure?/1" do
    assert secure?(URI.parse("https://example.org"))
    refute secure?(URI.parse("http://example.org"))
    refute secure?(URI.parse("ws://example.org"))
  end

  test "ip_address?/1" do
    assert ip_address?("0.0.0.0")
    assert ip_address?("1.2.3.4")
    assert ip_address?("255.255.155.255")
    assert ip_address?("0:0:0:0:0:0:0:0")
    assert ip_address?("::")
    assert ip_address?("2001:db8::")
    assert ip_address?("::1234:5678")
    assert ip_address?("2001:db8::1234:5678")
    assert ip_address?("2001:0db8:0001:0000:0000:0ab9:C0A8:0102")
    assert ip_address?("2001:db8:1::ab9:C0A8:102")

    refute ip_address?("example.org")
    refute ip_address?("some.example.org")
    refute ip_address?("some.more.example.org")
  end
end

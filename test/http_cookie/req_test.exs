defmodule HttpCookie.ReqTest do
  use ExUnit.Case, async: true

  alias HttpCookie.ReqPlugin

  test "end-to-end" do
    plug =
      fn
        %{request_path: "/one"} = conn ->
          conn
          |> Plug.Conn.put_resp_header("set-cookie", "foo=bar")
          |> Plug.Conn.resp(200, "Have a cookie")

        %{request_path: "/two"} = conn ->
          conn = Plug.Conn.fetch_cookies(conn)
          assert conn.req_cookies == %{"foo" => "bar"}

          conn
          |> Plug.Conn.prepend_resp_headers([
            {"set-cookie", "foo2=bar2"},
            {"set-cookie", "foo3=bar3"}
          ])
          |> Plug.Conn.resp(200, "Have some more")

        %{request_path: "/three"} = conn ->
          conn = Plug.Conn.fetch_cookies(conn)
          assert conn.req_cookies == %{"foo" => "bar", "foo2" => "bar2", "foo3" => "bar3"}

          conn
          |> Plug.Conn.resp(200, "No more cookies for you, come back one year")
      end

    empty_jar = HttpCookie.Jar.new()

    req =
      Req.new(base_url: "https://example.com", plug: plug)
      |> ReqPlugin.attach(cookie_jar: empty_jar)

    assert %{private: %{cookie_jar: updated_jar}} = Req.get!(req, url: "/one")

    original_access_time =
      updated_jar.cookies
      |> Map.fetch!("example.com")
      |> Map.fetch!(:cookies)
      |> Map.fetch!({"foo", "/"})
      |> Map.fetch!(:last_access_time)

    assert %{private: %{cookie_jar: updated_jar}} =
             Req.get!(req, url: "/two", cookie_jar: updated_jar)

    assert %{private: %{cookie_jar: updated_jar}} =
             Req.get!(req, url: "/three", cookie_jar: updated_jar)

    updated_access_time =
      updated_jar.cookies
      |> Map.fetch!("example.com")
      |> Map.fetch!(:cookies)
      |> Map.fetch!({"foo", "/"})
      |> Map.fetch!(:last_access_time)

    assert DateTime.after?(updated_access_time, original_access_time)
  end

  test "picks up cookies from redirect response" do
    plug =
      fn
        %{request_path: "/redirect-me"} = conn ->
          conn
          |> Plug.Conn.put_resp_header("set-cookie", "redirected=yes")
          |> Plug.Conn.put_resp_header("location", "/first-stop")
          |> Plug.Conn.resp(302, "Go away")

        %{request_path: "/first-stop"} = conn ->
          conn = Plug.Conn.fetch_cookies(conn)
          assert conn.req_cookies == %{"redirected" => "yes"}

          conn
          |> Plug.Conn.put_resp_header("set-cookie", "stopped=yeah")
          |> Plug.Conn.put_resp_header("location", "/final-destination")
          |> Plug.Conn.resp(302, "Almost there")

        %{request_path: "/final-destination"} = conn ->
          conn = Plug.Conn.fetch_cookies(conn)
          assert conn.req_cookies == %{"redirected" => "yes", "stopped" => "yeah"}

          Plug.Conn.resp(conn, 200, "You made it!")
      end

    empty_jar = HttpCookie.Jar.new()

    req =
      Req.new(base_url: "https://example.com", plug: plug, redirect_log_level: false)
      |> ReqPlugin.attach(cookie_jar: empty_jar)

    assert %{private: %{cookie_jar: _updated_jar}} = Req.get!(req, url: "/redirect-me")
  end

  test "doesn't override existing cookie header" do
    plug =
      fn
        %{request_path: "/redirect-me"} = conn ->
          conn
          |> Plug.Conn.put_resp_header("set-cookie", "redirected=yes")
          |> Plug.Conn.put_resp_header("location", "/first-stop")
          |> Plug.Conn.resp(302, "Go away")

        %{request_path: "/first-stop"} = conn ->
          conn = Plug.Conn.fetch_cookies(conn)
          assert conn.req_cookies == %{"there-can-only-be" => "one"}

          conn
          |> Plug.Conn.put_resp_header("set-cookie", "stopped=yeah")
          |> Plug.Conn.put_resp_header("location", "/final-destination")
          |> Plug.Conn.resp(302, "Almost there")

        %{request_path: "/final-destination"} = conn ->
          conn = Plug.Conn.fetch_cookies(conn)
          assert conn.req_cookies == %{"there-can-only-be" => "one"}

          Plug.Conn.resp(conn, 200, "You made it!")
      end

    empty_jar = HttpCookie.Jar.new()

    req =
      Req.new(base_url: "https://example.com", plug: plug, redirect_log_level: false)
      |> ReqPlugin.attach(cookie_jar: empty_jar)

    assert %{private: %{cookie_jar: _updated_jar}} =
             Req.get!(req, url: "/redirect-me", headers: [cookie: "there-can-only-be=one"])
  end
end

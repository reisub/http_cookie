defmodule HttpCookie.TestSupport.TeslaPlugAdapter do
  @moduledoc false

  @behaviour Tesla.Adapter

  alias Plug.Conn.Status

  @impl Tesla.Adapter
  def call(env, opts) do
    plug = Keyword.fetch!(opts, :plug)

    env =
      env
      |> env_to_conn()
      |> plug.()
      |> conn_to_env(env)

    {:ok, env}
  end

  defp env_to_conn(env) do
    uri = URI.parse(env.url)

    uri =
      if env.query in [nil, []] do
        uri
      else
        query = URI.encode_query(env.query)
        query_uri = URI.parse("?#{query}")
        URI.merge(uri, query_uri)
      end

    method =
      env.method
      |> to_string()
      |> String.upcase()

    port =
      case uri.scheme do
        "http" -> 80
        "https" -> 443
      end

    %Plug.Conn{
      host: uri.host,
      method: method,
      request_path: uri.path,
      path_info: String.split(uri.path, "/"),
      port: port,
      query_string: uri.query,
      scheme: String.to_atom(uri.scheme),
      req_headers: env.headers
    }
  end

  defp conn_to_env(conn, env) do
    %{
      env
      | status: Status.code(conn.status),
        headers: conn.resp_headers,
        body: conn.resp_body
    }
  end
end

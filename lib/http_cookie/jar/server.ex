defmodule HttpCookie.Jar.Server do
  use GenServer

  @moduledoc """
  HTTP Cookie Jar Server

  Thin GenServer wrapper around HttpCookie.Jar.
  This is a convenience to enable usage with HTTP clients
  which don't have a way to store and pass back the updated jar.
  """

  alias HttpCookie.Jar

  @doc """
  Starts the jar server.
  """
  @spec start_link() :: {:ok, pid()}
  @spec start_link(opts :: keyword()) :: {:ok, pid()}
  def start_link(opts \\ []) do
    jar = Keyword.get_lazy(opts, :jar, fn -> Jar.new() end)
    GenServer.start_link(__MODULE__, jar)
  end

  @doc """
  Processes the response header list for the given request URL.
  Parses set-cookie headers and stores valid cookies.
  """
  @spec put_cookies_from_headers(pid :: pid(), request_url :: URI.t(), headers :: list()) ::
          Jar.t()
  def put_cookies_from_headers(pid, request_url, headers) do
    GenServer.call(pid, {:put_cookies_from_headers, request_url, headers})
  end

  @doc """
  Formats the cookie for sending in a request header for the provided URL.
  """
  @spec get_cookie_header_value(pid :: pid(), request_url :: URI.t()) ::
          {:ok, String.t()} | {:error, :no_matching_cookies}
  def get_cookie_header_value(pid, request_url) do
    GenServer.call(pid, {:get_cookie_header_value, request_url})
  end

  @doc """
  Returns the internal cookie jar.
  """
  @spec get_cookie_jar(pid :: pid()) :: {:ok, Jar.t()}
  def get_cookie_jar(pid) do
    GenServer.call(pid, :get_cookie_jar)
  end

  @impl true
  def init(jar), do: {:ok, jar}

  @impl true
  def handle_call({:put_cookies_from_headers, request_url, headers}, _from, jar) do
    new_jar = Jar.put_cookies_from_headers(jar, request_url, headers)
    {:reply, :ok, new_jar}
  end

  def handle_call({:get_cookie_header_value, request_url}, _from, jar) do
    case Jar.get_cookie_header_value(jar, request_url) do
      {:ok, header_value, new_jar} ->
        {:reply, {:ok, header_value}, new_jar}

      {:error, :no_matching_cookies} ->
        {:reply, {:error, :no_matching_cookies}, jar}
    end
  end

  def handle_call(:get_cookie_jar, _from, jar) do
    {:reply, jar, jar}
  end
end

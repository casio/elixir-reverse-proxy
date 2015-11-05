store = %{}

defmodule ReverseProxy.Cache do
  import Plug.Conn
  alias ReverseProxy.Store

  @moduledoc """
  A basic caching layer for `ReverseProxy`.

  Upstream content servers may be slow. SSL/TLS
  negotiation may be slow. Caching a response from the
  upstream increases the potential performance of
  `ReverseProxy`.
  """

  @typedoc "Callback to retreive an upstream response"
  @type callback :: (Plug.Conn.t -> Plug.Conn.t)

  @doc """
  Entrypoint to serve content from the cache when available
  (cache hit) and from the upstream when not available
  (cache miss).
  """
  @spec serve(Plug.Conn.t, callback) :: Plug.Conn.t
  def serve(conn, upstream) do
    uri = "#{conn.request_path}?#{conn.query_string}"

    IO.inspect Store.get_all

    if Store.has? uri do
      res = Store.get(uri)
      Plug.Conn.send_resp conn, 200, res.body
    else
      {request, response} = upstream.(conn)
      Store.put uri, response
      request
    end
  end
end

defmodule ReverseProxy.Store do
  def start_link do
    Agent.start_link(fn -> HashDict.new end, name: __MODULE__)
  end

  def has?(key) do
    Agent.get(__MODULE__, fn dict ->
      Dict.has_key? dict, key
    end)
  end

  def put(key, val) do
    Agent.update(__MODULE__, &Dict.put(&1, key, val))
  end

  def get(key) do
    Agent.get(__MODULE__, fn dict ->
      dict |> Dict.get key
    end)
  end

  def get_all do
    Agent.get(__MODULE__, fn dict ->
      dict
    end)
  end
end

defmodule AtlasWeb.Plugs.HealthCheck do
  @moduledoc false
  @behaviour Plug
  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: "/health_check"} = conn, _opts) do
    conn
    |> send_resp(200, db_response())
    |> halt()
  end

  def call(conn, _opts), do: conn

  defp db_response do
    [date] = Ecto.Adapters.SQL.query!(Atlas.Repo, "select now();", []).rows |> List.flatten()
    date |> DateTime.to_string()
  end
end

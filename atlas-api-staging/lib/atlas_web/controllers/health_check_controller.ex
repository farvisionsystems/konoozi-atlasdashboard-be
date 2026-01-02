defmodule AtlasWeb.HealthCheckController do
  use AtlasWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(200)
    |> text("OK")
  end
end

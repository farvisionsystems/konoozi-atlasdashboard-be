defmodule AtlasWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :atlas

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_atlas_key",
    signing_salt: "qp1qWNuk",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  socket "/socket", AtlasWeb.UserSocket,
    websocket: [timeout: :infinity, connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :atlas,
    gzip: false,
    only: AtlasWeb.static_paths()

  plug Plug.Static,
    at: "/uploads",
    from: Path.expand("./uploads"),
    gzip: false

  plug CORSPlug, origin: "https://dash.atlassensordashboard.com"
  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :atlas
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # Adding Sentry's error capturing plug
  if Application.get_env(:sentry, :enable_error_reporting, true) do
    # <-- Add this line to capture errors
    use Sentry.PlugCapture
  end

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  # Adding Sentry context to attach additional request info
  # <-- Add this line to capture context
  plug Sentry.PlugContext
  plug AtlasWeb.Router
end

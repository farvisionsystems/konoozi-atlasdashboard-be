# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

with dotenv = "#{__DIR__}/../.env",
     {:ok, data} <- File.read(dotenv),
     do:
       for(
         "export" <> kv <- String.split(data, "\n"),
         [k, v] = String.split(kv, "=", parts: 2),
         do:
           k
           |> String.trim()
           |> System.put_env(
             v
             # Trim spaces
             |> String.trim()
             # Remove leading quotes
             |> String.trim_leading("\"")
             # Remove trailing quotes
             |> String.trim_trailing("\"")
             # Remove trailing backslash if any
             |> String.trim_trailing("\\")
             # Remove trailing carriage return
             |> String.trim_trailing("\r")
             # Remove trailing newline
             |> String.trim_trailing("\n")
           )
       )

config :atlas,
  ecto_repos: [Atlas.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :atlas, AtlasWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AtlasWeb.ErrorHTML, json: AtlasWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Atlas.PubSub,
  live_view: [signing_salt: "+DxpEMlU"]

config :acl, Acl.Repo, repo: Atlas.Repo
# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.

config :ueberauth, Ueberauth,
  providers: [
    google:
      {Ueberauth.Strategy.Google, [default_scope: "email profile", prompt: "select_account"]}
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

config :atlas,
       :frontend_base_url,
       System.get_env("FRONTEND_BASE_URL") || "https://dash.atlassensordashboard.com"

config :ex_aws, :hackney_opts,
  follow_redirect: true,
  recv_timeout: 30_000

config :atlas, :storage_service, Atlas.Cloud.FileStorage.Impl

config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  bucket: System.get_env("AWS_BUCKET"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  s3: [
    scheme: "https://",
    host: System.get_env("AWS_S3_HOST"),
    region: System.get_env("AWS_S3_REGION"),
    expires_in: 86400,
    virtual_host: false
  ]

config :atlas, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      router: AtlasWeb.Router,
      endpoint: AtlasWeb.Endpoint
    ]
  }

config :arc,
  storage: Arc.Storage.Local,
  storage_dir: "uploads"

config :phoenix_swagger, json_library: Jason
# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  atlas: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  atlas: [
    args: ~w(
    --config=tailwind.config.js
--input=css/app.css
--output=../priv/static/assets/app.css
),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :atlas, Atlas.Scheduler,
  jobs: [
    {"0 0 * * *", {Atlas.Scheduler, :run_reports, []}}

  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

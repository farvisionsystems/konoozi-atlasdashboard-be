defmodule AtlasWeb.Router do
  use AtlasWeb, :router
  require Logger

  import AtlasWeb.UserAuth

  if Mix.env() == :dev do
    forward("/sent_emails", Bamboo.SentEmailViewerPlug)
  end

  pipeline :browser do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AtlasWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    # Add this plug to capture errors for Sentry
    plug Sentry.PlugContext
  end

  pipeline :api do
    plug :accepts, ["json"]
    # plug :fetch_current_user
    # Add this plug to capture errors for Sentry
    plug Sentry.PlugContext
    plug :log_request
  end

  pipeline :role_based_api do
    plug :fetch_logged_in_user
    plug Atlas.Plugs.APIAuthorization
  end

  scope "/", AtlasWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", AtlasWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in all environments
  if Application.compile_env(:atlas, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AtlasWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  scope "/health_check" do
    forward("/", AtlasWeb.Plugs.HealthCheck)
  end

  ## Authentication routes

  scope "/api", AtlasWeb do
    pipe_through [:api, :redirect_if_user_is_authenticated]

    post "/users/register", UserController, :create
    post "/users/log_in", UserSessionController, :create
    post "/users/reset_password", UserResetPasswordController, :create
    post "/users/reset_password/verify_token", UserResetPasswordController, :verify_otp_and_email
    put "/users/reset_password", UserResetPasswordController, :update
    get "/users/invite/:token", UserInviteController, :show

    get("/auth/:provider", AuthController, :request)
    get("/auth/:provider/callback", AuthController, :callback)
    get("health_check", HealthCheckController, :index)
  end

  scope "/api", AtlasWeb do
    pipe_through [:browser]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/api", AtlasWeb do
    pipe_through [:api]

    post "/resource/atlas/dom/:gateway_slug", DomController, :create
    post "/commands", CommandController, :create
    delete "/commands/:id", CommandController, :delete
    get "/commands", CommandController, :index
    get "/organizations/exists/:name", OrganizationController, :exists
    delete "/maintenance/delete_nil_role", MaintenanceController, :delete_users_and_organizations_with_nil_role
  end

  # Generic routes that every logged users needs to have
  scope "/api", AtlasWeb do
    pipe_through [:api, :fetch_logged_in_user]

    put "/user/switch_org", UserController, :switch_active_organization
    delete "/user/log_out", UserSessionController, :log_out
    get "/current_user", UserController, :show_current_user
    put "/user/profile", ProfileController, :update_profile
    post "/upload_image", ImageController, :create
    resources "/organizations", OrganizationController, only: [:create, :index, ]

    delete "/user/delete", BuyerController, :delete_user
    # Buyer's routes
    get "/buyers", BuyerController, :index
    get "/buyer/:id", BuyerController, :show
    get "/user_buyers", BuyerController, :user_buyers
    get "/other_buyers", BuyerController, :other_buyers
    get "/favourite_buyers", BuyerController, :favourite_buyers
    post "/favourite_buyer/:buyer_id", BuyerController, :favourite_buyer
    post "/buyer", BuyerController, :create
    post "/filtered_buyers", BuyerController, :filtered_buyers
    post "/search_buyers/:zip_code", BuyerController, :search_buyers
    put "/buyer/:id", BuyerController, :update
    # Note for buyer route
    post "/buyer_note/:buyer_id", NoteController, :create
    # Uploading image route
    # Location's routes
    get "/locations", LocationController, :index
    get "/location/:zip_code", LocationController, :show
    get "/states", LocationController, :state_index
    post "/buyer_locations", LocationController, :buyer_locations
    # Auth provider routes
    post "/auth_provider", AuthProviderController, :create
    get "/users/dashboard/:id", UserDashboardController, :show
    post "/reports", ReportController, :create
    get "/reports", ReportController, :index
    put "/reports/sensors", ReportController, :set_sensors
    get "/reports/:id", ReportController, :show
    put "/reports/:id", ReportController, :update
    put "/reports/:report_id/distribution", ReportController, :save_distribution
    post "/reports/:report_uid/run", ReportController, :run_report
    get "/reports/:report_id/history", ReportController, :report_history
    delete "/reports/:id", ReportController, :delete
    delete "/reports/data/:id", ReportController, :delete_report_data
    resources "/organizations", OrganizationController, only: [:delete, :update]


  end

  scope "/api", AtlasWeb do
    pipe_through [:api, :role_based_api]

    resources "/acl", AclController
    resources "/devices", DeviceController
    post "/devices/update_sensor_inputs", DeviceController, :update_sensor_inputs
    get "/devices/:id/sensors", DeviceController, :get_device_sensors
    get "/devices/alarm/list", DeviceController, :alarm_devices
    delete "/organizations/query/delete_all_except_12", OrganizationController, :delete_all_except_12

    # User's routes
    post "/users/invite", UserInviteController, :create
    post "/users/acl", AclController, :only_roles
    put "/users/:id", UserController, :update
    get "/users/:id", UserController, :show
    get "/users", UserController, :index
    get "/dashboard/statistics", UserController, :get_statistics
    post "/users/create", UserInviteController, :create_user
    get "/users/dashboard", UserDashboardController, :show
    put "/user/password", UserController, :update_password

    # Alarm Settings Routes
    get "/devices/:id/alarm_settings", DeviceAlarmSettingsController, :show
    put "/devices/:id/alarm_settings", DeviceAlarmSettingsController, :update
    get "/organizations/:id/alarm_settings", OrganizationAlarmSettingsController, :show
    put "/organizations/:id/alarm_settings", OrganizationAlarmSettingsController, :update

    # Export Routes
    get "/export/config", ExportController, :get_export_config
    post "/export/data", ExportController, :export_data

  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :atlas,
      swagger_file: "swagger.json"
  end

  def swagger_info do
    %{
      schemes: ["https", "http", "ws", "wss"],
      host: "bb.vdev.tech/api",
      info: %{
        version: "1.0",
        title: "MyAPI",
        description: "API Documentation for MyAPI v1",
        termsOfService: "Open for public",
        contact: %{
          name: "Vladimir Gorej",
          email: "vladimiir.gore@gmail.com"
        }
      },
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          description: "Api Token must be provided via `Authorization: Bearer ` header",
          in: "header"
        }
      },
      consumes: ["application/json"],
      produces: ["application/json"],
      tags: [
        %{name: "Users", description: "User resources"}
      ]
    }
  end

  defp log_request(conn, _opts) do
    Logger.info("Incoming request: #{conn.method} #{conn.request_path}")
    IO.inspect(conn.params)
    conn
  end
end

defmodule AtlasWeb.AuthController do
  use AtlasWeb, :controller
  plug(Ueberauth)
  require Logger

  alias AtlasWeb.UserAuth

  def request(conn, _params) do
    render(conn, "", callback_url: Ueberauth.Strategy.Helpers.callback_url(conn))
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Atlas.Accounts.register_user_by_social(auth) do
      {:ok, user} ->
        token = Atlas.Accounts.generate_user_session_token(user) |> Base.url_encode64()
        role = Atlas.Roles.get_role_rules_by_user_organization(user.id, user.organization_id)

        user =
          Map.put(user, "token", token)
          |> Map.put("role", role)
          |> Atlas.Repo.preload(:profile)

        message = %{title: nil, body: "Successfully signed up"}

        render(conn, AtlasWeb.UserView, "user.json", %{user: user, message: message})

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render(AtlasWeb.UserView, "error.json", error: error)

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> render(AtlasWeb.UserView, "message.json", %{message: message})
    end
  end
end

defmodule AtlasWeb.UserDashboardController do
  use AtlasWeb, :controller
  alias Atlas.Accounts
  alias Atlas.Repo

  def show(conn, %{"id" => user_id}) do
    user =
      Atlas.Accounts.get_user(user_id)
      # Ensure user_organizations and roles are preloaded
      |> Repo.preload(user_organizations: [:role])

    # Get the user's role (for the first org, or adjust as needed)
    user_org = List.first(user.user_organizations)
    role = if user_org && user_org.role, do: user_org.role.role, else: nil

    role =
      if user.id != 202 and role == "super_admin" do
        "admin"
      else
        role
      end

    full_name = "#{user.first_name || ""} #{user.last_name || ""}"
    stats = Accounts.get_dashboard_stats(user.id, role, user.organization_id, full_name)
    conn
    |> put_status(:ok)
    |> json(%{stats: stats, role: role})
  end
end

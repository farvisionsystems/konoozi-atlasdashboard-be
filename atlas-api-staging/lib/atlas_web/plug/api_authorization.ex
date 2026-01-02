defmodule Atlas.Plugs.APIAuthorization do
  import Plug.Conn
  import Phoenix.Controller
  alias Atlas.Roles

  def init(default), do: default

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]
    api_path = conn.request_path
    http_method = conn.method
    if current_user.id === 202 || has_permission?(current_user, api_path, http_method) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "unauthorized"})
      |> halt()
    end
  end

  defp has_permission?(nil, _api_path, _http_method), do: false

  defp has_permission?(
         %{organization_id: organization_id, user_organizations: user_organizations} = user,
         api_path,
         http_method
       ) do
    # Check if user is active
    if not user.is_active do
      false
    else
      # Find the user's organization record
      user_org = Enum.find(user_organizations, fn x -> x.organization_id == organization_id end)

      # Check if user_organization exists and is active
      if is_nil(user_org) or user_org.status != "Active" do
        false
      else
        # Get organization and check if it's active
        organization = Atlas.Repo.get(Atlas.Organizations.Organization, organization_id)
        if is_nil(organization) or not organization.is_active do
          false
        else
          {role, rules} =
            user_org
            |> Map.get(:role_id)
            |> Roles.get_rules_by_role_id()

          rule =
            Enum.find(rules, fn rule ->
              String.contains?(api_path, "/#{rule.resource.resource}")
            end)

          case {role, rule} do
            {"super_admin", _} -> true
            {"admin", _} -> true
            {"user", _} -> true
            {_, %{permission: permission}} -> to_action(http_method) <= permission
            _ -> false
          end
        end
      end
    end
  end

  def to_action("GET"), do: 1
  def to_action("POST"), do: 2
  def to_action("DELETE"), do: 3
  def to_action("PUT"), do: 4
  def to_action("PATCH"), do: 4
end

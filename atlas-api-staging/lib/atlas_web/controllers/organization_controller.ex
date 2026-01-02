defmodule AtlasWeb.OrganizationController do
  use AtlasWeb, :controller

  alias Atlas.{Organizations, Organizations.Organization, Accounts}

  def index(%{assigns: %{current_user: current_user}} = conn, _params) do
    current_user.user_organizations

    organizations =
      Enum.map(current_user.user_organizations, & &1.organization_id)
      |> Organizations.get_organizations()

    organizations =
      Enum.map(organizations, fn organization ->
        user_organization =
          Enum.find(current_user.user_organizations, &(&1.organization_id == organization.id))

        %{"is_creator" => user_organization.is_creator, "role" => user_organization.role.role}
        |> Map.merge(organization)
      end)

    message = %{title: nil, body: "Successfully loaded organization"}

    conn
    |> put_status(:created)
    |> render("show.json", %{organizations: organizations, message: message})
  end

  def create(%{assigns: %{current_user: current_user}} = conn, params) do
    params = Map.put(params, "user_id", current_user.id)

    with {:ok, %Organization{} = organization} <-
           Organizations.create_organization(params, current_user.id) do
      message = %{title: nil, body: "Successfully added organization"}

      updated_organization =
        Map.put(organization, "is_creator", true) |> Map.put("role", "super_admin")

      conn
      |> put_status(:created)
      |> render("show.json", %{
        organization: updated_organization,
        message: message
      })
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render("error.json", error: error)

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: %{message: "Invalid params"})
    end
  end

  def update(%{assigns: %{current_user: current_user}} = conn, params) do
    with {:ok, %Organization{} = organization} <-
           Organizations.update_organization(params["id"], params) do
      # Handle user activation/deactivation based on organization status
      case Map.get(params, "is_active") do
        true -> Accounts.activate_all_users_in_organization(organization.id)
        false -> Accounts.deactivate_all_users_in_organization(organization.id)
        _ -> :ok
      end

      message = %{title: nil, body: "Successfully updated organization"}

      conn
      |> put_status(:created)
      |> render("show.json", %{
        organization: organization,
        message: message
      })
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render("error.json", error: error)

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: %{message: "Invalid params"})
    end
  end

  def delete(%{assigns: %{current_user: current_user}} = conn, params) do
    with %{organization_id: organization_id} <-
           Enum.find(current_user.user_organizations, fn uo ->
             uo.organization_id == String.to_integer(params["id"])
           end),
         {:ok, _} <-
           Organizations.delete_organization(organization_id, false) do
      message = %{title: nil, body: "Successfully deleted organization"}

      conn
      |> put_status(:ok)
      |> render("show.json", %{message: message})
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: %{message: "Invalid params"})
    end
  end

  def exists(conn, %{"name" => name}) do
    case Organizations.get_organization_by_name(name) do
      nil ->
        conn
        |> put_status(:ok)
        |> json(%{exists: false})

      _organization ->
        conn
        |> put_status(:ok)
        |> json(%{exists: true})
    end
  end

  def delete_all_except_12(%{assigns: %{current_user: current_user}} = conn, _params) do
    # Only allow super_admin to perform this action
    user_org = Enum.find(current_user.user_organizations, &(&1.organization_id == current_user.organization_id))

    if user_org && user_org.role.role == "super_admin" do
      case Organizations.delete_all_organizations_except() do
        {:ok, message} ->
          conn
          |> put_status(:ok)
          |> json(%{message: message})

        {:error, changeset} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: translate_errors(changeset)})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: %{message: "Unauthorized to perform this action"}})
    end
  end
end

defmodule AtlasWeb.AclController do
  use AtlasWeb, :controller

  alias Atlas.{Repo, Roles}

  def index(%{assigns: %{current_user: current_user}} = conn, _params) do
    acl = Roles.get_role_resource_rules(current_user.organization_id)

    message = %{title: nil, body: "Successfully loaded Roles with Rules"}

    conn
    |> put_status(:created)
    |> render("acl.json", %{acl: acl, message: message})
  end

  def only_roles(%{assigns: %{current_user: current_user}} = conn, _params) do
    roles = Roles.get_roles(current_user.organization_id)

    message = %{title: nil, body: "Successfully loaded Roles"}

    conn
    |> put_status(:created)
    |> render("role.json", %{role: roles, message: message})
  end

  def create(%{assigns: %{current_user: current_user}} = conn, params) do
    Roles.create_role_with_rules(params, current_user.organization_id)
    |> case do
      {:ok, role} ->
        message = %{title: nil, body: "Successfully created Role"}

        conn
        |> put_status(:created)
        |> render("role.json", %{role: role, message: message})

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render(AtlasWeb.UserView, "error.json", error: error)

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("message.json", %{message: "Invalid params"})
    end
  end

  def update(%{assigns: %{current_user: current_user}} = conn, params) do
    with {:ok, _} <-
           Roles.update_rules(params) do
      message = %{title: nil, body: "Successfully updated Rules"}

      conn
      |> put_status(:created)
      |> render("message.json", %{message: message})
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: %{message: "Invalid params"})
    end
  end

  def delete(%{assigns: %{current_user: current_user}} = conn, params) do
    Roles.delete_role(params["id"])
    |> case do
      {:ok, _} ->
        message = %{title: nil, body: "Successfully deleted role"}

        conn
        |> put_status(:ok)
        |> render("message.json", %{message: message})

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render(AtlasWeb.UserView, "error.json", error: error)

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("message.json", %{
          message: "Cannot delete role because users are associated with it"
        })
    end
  end
end

defmodule AtlasWeb.UserInviteController do
  use AtlasWeb, :controller

  @frontend_base_url Application.get_env(:atlas, :frontend_base_url)
  alias Atlas.Accounts

  def create(
        %{assigns: %{current_user: current_user}} = conn,
        %{
          "email" => email,
          "role_id" => role_id
        } = params
      ) do
    organization_id = current_user.organization_id
    downcased_email = String.downcase(email)
    user_status = Accounts.email_for_organization(downcased_email, organization_id)

    with true <- user_status in [:not_in_system, :not_in_org],
         {:ok, invite_token} <-
           Accounts.InviteToken.generate_invite_token(downcased_email, role_id, organization_id) do
      link = @frontend_base_url <> "/organizations/invitation/" <> invite_token.token
      Accounts.UserNotifier.deliver_invite_email(invite_token, link)

      conn
      |> put_status(:ok)
      |> render("message.json", %{message: "Invite link sent successfully, #{link}"})
    else
      false ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", %{error: "User already exists in organization"})

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", %{error: "Invalid params"})
    end
  end



  def create_user2(
    %{assigns: %{current_user: current_user}} = conn,
    %{
      "email" => email,
      "organization" => organization,
      "password" => password,
      "first_name" => first_name,
      "last_name" => last_name
    } = params
  ) do
    downcased_email = String.downcase(email)
    role = Map.get(params, "role", "user")
    case Accounts.get_user_by_email(downcased_email) do
      nil ->
        # Create organization first
        with {:ok, organization} <- Atlas.Organizations.create_organization_with_out_user(organization),
             # Then create user with the organization and creator
             {:ok, user} <- Accounts.User.create_user(%{
               "email" => downcased_email,
               "password" => password,
               "first_name" => first_name,
               "last_name" => last_name,
               "organization_id" => organization.id,
               "created_by_id" => current_user.id,
               "role" => role
             }, current_user) do

          conn
          |> put_status(:created)
          |> json(%{ message: "success"})
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render("error.json", %{error: "Failed to create user", details: changeset.errors})

          {:error, :activation_failed} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render("error.json", %{error: "Failed to activate user in organization"})

          error ->
            conn
            |> put_status(:internal_server_error)
            |> render("error.json", %{error: "Something went wrong"})
        end

      _existing_user ->
        conn
        |> put_status(:conflict)
        |> render("error.json", %{error: "User with this email already exists"})
    end
  end

  def show(conn, %{"token" => token}) do
    Accounts.InviteToken.validate_invite_token(token)
    |> case do
      {:ok, invite_token} ->
        user_status =
          Accounts.email_for_organization(invite_token.email, invite_token.organization_id)

        redirect = if user_status == :not_in_system, do: "signup", else: "login"

        conn
        |> put_status(:ok)
        |> render("invite.json", %{
          invite: Map.put(invite_token, "redirect", redirect),
          message: "Token is valid"
        })

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", %{error: message})
    end
  end

  @spec create_user_in_organization(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_user_in_organization(
    %{assigns: %{current_user: current_user}} = conn,
    %{
      "email" => email,
      "organization" => organization,
      "password" => password,
      "first_name" => first_name,
      "last_name" => last_name,
      "role" => role
    } = params
  ) do
    downcased_email = String.downcase(email)
    case Accounts.get_user_by_email(downcased_email) do
      nil ->
        # Create organization first
        with {:ok, organization} <- Atlas.Organizations.create_organization_with_out_user(organization),
             # Then create user with the organization and creator
             attrs = %{
               "email" => downcased_email,
               "password" => password,
               "first_name" => first_name,
               "last_name" => last_name,
               "organization_id" => organization.id,
               "role" => Map.get(params, "role", "user")
             } do
          case Accounts.create_user_in_organization(attrs, current_user.id, organization.id) do
            {:ok, user} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "success"})

            {:error, changeset} ->
              conn
              |> put_status(:bad_request)
              |> json(%{error: "Failed to create user"})
          end
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render("error.json", %{error: "Failed to create user", details: changeset.errors})

          {:error, :activation_failed} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render("error.json", %{error: "Failed to activate user in organization"})

          error ->
            conn
            |> put_status(:internal_server_error)
            |> render("error.json", %{error: "Something went wrong"})
        end

      _existing_user ->
        conn
        |> put_status(:conflict)
        |> render("error.json", %{error: "User with this email already exists"})
    end
  end


  def create_user(conn, user_params) do
    organization_id = if user_params["organization"] === "",
      do: conn.assigns.current_user.organization_id,
      else: nil
    user_params = Map.put(user_params, "organization_id", organization_id)

    user_params = Map.put(user_params, "created_by_id", conn.assigns.current_user.id)
    case Accounts.do_create_user(user_params, {user_params["role"], organization_id}) do
      {:ok, user} ->

        conn
        |> put_status(:ok)
        |> json(%{message: "success", user: user})

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render("error.json", error: error)

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> render("message.json", %{message: message})
    end
  end

end

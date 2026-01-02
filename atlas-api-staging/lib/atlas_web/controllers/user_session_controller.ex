defmodule AtlasWeb.UserSessionController do
  use AtlasWeb, :controller

  alias Atlas.{Accounts, Organizations, Organizations.UserOrganization}

  def create(conn, %{"email" => email, "password" => password} = params) do
    downcased_email = String.downcase(email)
    user = Accounts.get_user_by_email_and_password(downcased_email, password)

    login(user, Map.get(params, "token"))
    |> case do
      {:ok, :log_in_with_invite} ->
        token = Accounts.generate_user_session_token(user) |> Base.url_encode64()
        role = Atlas.Roles.get_role_rules_by_user_organization(user.id, user.organization_id)

        user =
          Map.put(user, "token", token)
          |> Map.put("role", role)
          |> Atlas.Repo.preload(:profile)

        message = %{title: nil, body: "Successfully logged in with invite"}
        render(conn, "user.json", user: user, message: message)

      {:ok, :log_in_without_invite} ->
        token = Accounts.generate_user_session_token(user) |> Base.url_encode64()
        role = Atlas.Roles.get_role_rules_by_user_organization(user.id, user.organization_id)

        user =
          Map.put(user, "token", token)
          |> Map.put("role", role)
          |> Atlas.Repo.preload(:profile)

        message = %{title: nil, body: "Successfully logged in"}
        render(conn, "user.json", user: user, message: message)

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> render("message.json", %{message: message})
    end
  end

  def log_out(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: "User not logged in")
  end

  def log_out(%{assigns: %{current_user: _user, session_token: token}} = conn, _params) do
    token && Accounts.delete_user_session_token(Base.url_decode64!(token))
    render(conn, "user.json", message: "Successfully logged out")
  end

  defp login(nil, _), do: {:error, "Email password is incorrect!"}

  defp login(user, nil) do
    {:ok, :log_in_without_invite}
  end

  defp login(user, invite_token) do
    with {:ok, invite_struct} <- Accounts.InviteToken.validate_invite_token(invite_token),
         {:ok, _} <- Accounts.create_user_from_invite(user, invite_struct) do
      {:ok, :log_in_with_invite}
    else
      {:error, message} -> {:error, message}
    end
  end

  # Swagger Implementations
  swagger_path :create do
    post("/users/log_in")
    summary("Login User")

    description("Login user")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:CreateSession), "Create New Session for user by passing params",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:users))
  end

  swagger_path :log_out do
    delete("/users/log_out")
    summary("Logout User")

    description("Logout User")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:DeleteSession), "Logout user and delete it's token", required: true)
    end

    response(200, "Successfully logged out")
  end

  def swagger_definitions do
    %{
      CreateSession:
        swagger_schema do
          title("Login User")
          description("Login user by passing valid email and password")

          properties do
            email(:string, "User email must have the @ sign and no spaces")
            password(:string, "Pasword must be min 12 and max 72")
          end

          example(%{
            email: "admin@admin.com",
            password: "password@123"
          })
        end,
      DeleteSession:
        swagger_schema do
          title("Logout User")
          description("Logout user by passing token")

          properties do
          end

          example(%{})
        end,
      users:
        swagger_schema do
          properties do
            id(:integer, "User unique id")
            email(:string, "Email Value", required: true)
            password(:string, "Password Value", required: true)
            phone_number_primary(:string, "Primary phone number")
            first_name(:string, "First name of user")
            last_name(:string, "Last name of user")
            image_url(:string, "Avatar Url")
            hashed_password(:string, "Hashed Password")
            brokerage_name(:string, "Broker's Name")
            brokerage_lisence_no(:string, "Broker's lisence number")
            lisence_id_no(:string, "Lisence ID number")
            broker_street_address(:string, "Broker's Street Address")
            broker_city(:string, "Broker's City")
            brokerage_zip_code(:string, "Broker's zip code")
            brokerage_state(:string, "Broker's State")
            confirmed_at(:string, "User confirmed at Datetime")
            inserted_at(:string, "User inserted at Datetime")
            updated_at(:string, "User updated at Datetime")
          end

          example(%{
            data: %{
              confirmed_at: "2024-05-20T20:20:37Z",
              email: "admin4@admin.com",
              hashed_password: "$2b$12$xzVN8p9own/R6BijKKqRXuOgWjXCrRcWavf6S6j5eZ3eXHHAt421u",
              phone_number_primary: "+123456",
              first_name: "First Name",
              last_name: "Last Name",
              image_url: "/avatar.png",
              id: 26,
              inserted_at: "2024-05-20T20:20:37Z",
              password: "2024-05-20T20:20:37Z",
              updated_at: "2024-05-20T20:20:37Z",
              token: "R7-vrW98kLb-CyAKHWeRo8im2wxOdOcTd_pwHAJc9uE=",
              brokerage_name: "Broker Name",
              brokerage_lisence_no: "LIS1234",
              lisence_id_no: "REVS12345",
              broker_street_address: "123, Hope Street",
              broker_city: "New York",
              brokerage_zip_code: "12345",
              brokerage_state: "CA"
            },
            message: %{
              body: "Successfully signed up",
              title: "null"
            }
          })
        end,
      users_tokens:
        swagger_schema do
          properties do
            token(:string, "Token generated as a session for users when login or signup")
            context(:string, "Token generated either for session/email")
          end

          example(%{
            data: %{
              confirmed_at: "2024-05-20T19:28:36Z",
              email: "admin@admin.com",
              hashed_password: "$2b$12$AfWcJ0KcmMjMgVSiClPTiOsCfn.2XpG4aB15DCesfqDw.9gdXAd7a",
              id: 23,
              inserted_at: "2024-05-20T19:28:36Z",
              password: "2024-05-20T19:28:36Z",
              updated_at: "2024-05-20T19:28:36Z",
              token: "YXLdNjTlPUwQI54SCC_YoXEF1Lx_XrK6vHjRYvUoRjU="
            },
            message: %{
              body: "Successfully logged in",
              title: "null"
            }
          })
        end
    }
  end
end

defmodule AtlasWeb.ProfileController do
  use AtlasWeb, :controller

  alias Atlas.{Accounts, Accounts.User, Profile}

  def update_profile(%{assigns: %{current_user: nil}} = conn, _user_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def update_profile(%{assigns: %{current_user: %{id: id}}} = conn, user_params) do
    with user <- Accounts.get_user(id),
         params <- Map.put(user_params, "user_id", id),
         {:ok, %Profile{} = profile} <-
           Accounts.update_users_profile(user.profile || %Profile{}, params) do
      message = %{title: nil, body: "Successfully Updated profile"}

      render(conn, "profile.json", %{profile: profile, message: message})
    else
      e ->
        case e do
          {:error, %Ecto.Changeset{} = changeset} ->
            error = translate_errors(changeset)

            conn
            |> put_status(:bad_request)
            |> render("error.json", error: error)

          true ->
            conn
            |> put_status(:bad_request)
            |> render("error.json", error: %{message: "User not found"})

          {:error, :unauthorized} ->
            conn
            |> put_status(:bad_request)
            |> render("error.json", error: %{message: "Unauthenticated"})
        end
    end
  end

  # Swagger Implementation
  swagger_path :update_profile do
    put("/users/profile")
    summary("Updates Profile")

    description("Updates logged in user's profile")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:UpdateProfile), "Create New User by passing params", required: true)
    end

    response(200, "Ok", Schema.ref(:users))
  end

  def swagger_definitions do
    %{
      UpdateProfile:
        swagger_schema do
          title("Updates user's profile")
          description("Updates user's profile")

          properties do
            first_name(:string, "User's first name")
            last_name(:string, "User's last name")
            agent_email(:string, "User email must have the @ sign and no spaces")
            phone_number_primary(:string, "User's primary phone number")
            image_url(:string, "User's avatar url")
            brokerage_name(:string, "Broker's Name")
            brokerage_lisence_no(:string, "Broker's lisence number")
            lisence_id_no(:string, "Lisence ID number")
            broker_street_address(:string, "Broker's Street Address")
            broker_city(:string, "Broker's City")
            brokerage_zip_code(:string, "Broker's zip code")
            brokerage_state(:string, "Broker's State")
          end

          example(%{
            agent_email: "admin@admin.com",
            first_name: "User's first Name",
            last_name: "User's last Name",
            phone_number_primary: "+012345789",
            image_url: "/uploads/9C96BFEA-4192-4396-AC69-41234EE55236_1_201_a.png",
            brokerage_name: "Broker Name",
            brokerage_lisence_no: "LIS1234",
            lisence_id_no: "REVS12345",
            broker_street_address: "123, Hope Street",
            broker_city: "New York",
            brokerage_zip_code: "12345",
            brokerage_state: "CA"
          })
        end,
      users:
        swagger_schema do
          properties do
            id(:integer, "User unique id")
            email(:string, "Email Value", required: true)
            phone_number_primary(:string, "Primary phone number")
            first_name(:string, "First name of user")
            last_name(:string, "Last name of user")
            image_url(:string, "Avatar url")
            brokerage_name(:string, "Broker's Name")
            brokerage_lisence_no(:string, "Broker's lisence number")
            lisence_id_no(:string, "Lisence ID number")
            broker_street_address(:string, "Broker's Street Address")
            broker_city(:string, "Broker's City")
            brokerage_zip_code(:string, "Broker's zip code")
            brokerage_state(:string, "Broker's State")
            inserted_at(:string, "User inserted at Datetime")
            updated_at(:string, "User updated at Datetime")
          end

          example(%{
            data: %{
              agent_email: "admin4@admin.com",
              id: 26,
              inserted_at: "2024-05-20T20:20:37Z",
              updated_at: "2024-05-20T20:20:37Z",
              phone_number_primary: "+123456",
              first_name: "First Name",
              last_name: "Last Name",
              image_url: "/avatar.png",
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
        end
    }
  end
end

defmodule AtlasWeb.UserController do
  use AtlasWeb, :controller
  import Ecto.Query, warn: false
  alias Atlas.{Accounts, Organizations, Repo, Profile, User}
  alias Accounts.User

  def show_current_user(%{assigns: %{current_user: current_user}} = conn, _) do
    case Accounts.get_user(current_user.id) do
      %User{} = user ->
        message = %{title: nil, body: "Successfully fetched user"}

        role = Atlas.Roles.get_role_rules_by_user_organization(user.id, user.organization_id)
        user = Map.put(user, "role", role)
        render(conn, "user.json", %{user: user, message: message})

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: "User not found")
    end
  end



  def show(conn, %{"id" => user_id}) do
    case Accounts.get_user(user_id) do
      %User{} = user ->
        message = %{title: nil, body: "Successfully fetched user"}

        role = Atlas.Roles.get_role_rules_by_user_organization(user.id, user.organization_id)
        user = Map.put(user, "role", role)
        render(conn, "user.json", %{user: user, message: message})

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: "User not found")
    end
  end

  def index(%{assigns: %{current_user: current_user}} = conn, _) do
    user_org = hd(current_user.user_organizations)
    users = Accounts.get_all_users_with_organization_and_role(user_org.organization_id, current_user.id)

    message = %{title: nil, body: "Successfully fetched user"}

    render(conn, "users.json", %{users: users, message: message})
  end

  def update(%{assigns: %{current_user: current_user}} = conn, %{
        "id" => user_id,
        "is_active" => is_active
      }) do
    case Accounts.update_user_active_status(user_id, is_active) do
      {:ok, _} ->
        message = %{title: nil, body: "Successfully updated user status"}
        render(conn, "message.json", %{message: message})

      _ ->
        conn
        |> put_status(:bad_request)
        |> render(AtlasWeb.UserInviteView, "error.json", %{error: "Failed to update user status"})
    end
  end

  def update(%{assigns: %{current_user: current_user}} = conn, %{
        "id" => user_id,
        "user" => "remove"
      }) do
    with %{} = user_org <- Enum.find(current_user.user_organizations, fn uo ->
      uo.organization_id == current_user.organization_id
    end),
    {:ok, _} <- Accounts.update_user_active_status(user_id, false),
    {:ok, _} <- Organizations.remove_user_from_organization(user_id, current_user.organization_id) do
      message = %{title: nil, body: "Successfully removed user from organization"}
      render(conn, "message.json", %{message: message})
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> render(AtlasWeb.UserInviteView, "error.json", %{error: "Failed to remove user"})
    end
  end

  def update_password(%{assigns: %{current_user: _current_user}} = conn, %{
    "user_id" => user_id,
    "password" => password
  }) do
    with user <- Accounts.get_user(user_id),
    password when not is_nil(password) <- password,
    {:ok, _} <- Accounts.update_user_password2(user, password, %{
      "password" => password,
      "password_confirmation" => password
    }) do
      message = %{title: nil, body: "Password updated successfully"}
      render(conn, "message.json", %{message: message})
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> render("error.json", error: "User not found")

      nil ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: "Password is required")

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", error: error)
    end
  end

  def switch_active_organization(%{assigns: %{current_user: current_user}} = conn, %{
        "id" => organization_id
      }) do
    with %{} <-
           Enum.find(current_user.user_organizations, fn uo ->
             uo.organization_id == organization_id
           end),
         {:ok, user} <- Accounts.update_user_active_organization(current_user, organization_id) do
      message = %{title: nil, body: "Successfully updated active organization user"}
      role = Atlas.Roles.get_role_rules_by_user_organization(user.id, user.organization_id)

      user = Map.put(user, "role", role)

      render(conn, "user.json", %{user: user, message: message})
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> render(AtlasWeb.UserInviteView, "error.json", %{error: "Failed to update account"})
    end
  end

  def create(conn, user_params) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        role = Atlas.Roles.get_role_rules_by_user_organization(user.id, user.organization_id)
        token = Accounts.generate_user_session_token(user) |> Base.url_encode64()
        user = Map.put(user, "token", token) |> Map.put("role", role)

        message = %{title: nil, body: "Successfully signed up"}

        render(conn, "user.json", %{user: user, message: message})

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

  def update_or_create_profile(user, user_params) do
    profile_changeset =
      case Repo.get_by(Profile, user_id: user.id) do
        nil ->
          # If profile doesn't exist, create a new one with provided values
          %Profile{}
          |> Profile.changeset(%{
            user_id: user.id,
            first_name: Map.get(user_params, "first_name"),
            last_name: Map.get(user_params, "last_name"),
            agent_email: Map.get(user_params, "email")
          })

        profile ->
          # If profile exists, only update first_name and last_name if they are nil
          updated_params = %{
            first_name: profile.first_name || Map.get(user_params, "first_name"),
            last_name: profile.last_name || Map.get(user_params, "last_name")
          }

          profile
          |> Profile.changeset(updated_params)
      end

    Repo.insert_or_update(profile_changeset)
  end

  def get_statistics(%{assigns: %{current_user: current_user}} = conn, _) do
    # Get users with their creation dates and status
    users = Accounts.get_users(current_user.organization_id, current_user)
    |> Enum.map(fn user ->
      %{
        id: user.id,
        email: user.email,
        created_at: user.inserted_at,
        status: get_user_status(user)
      }
    end)
    total_users = length(users)

    # Get user's role from their organization
    user_org = hd(current_user.user_organizations)
    role = user_org.role.role

    # Get devices with their status
    devices = Atlas.Devices.get_devices(current_user.organization_id, role, current_user.id)
    devices_with_status = devices
    |> Enum.map(fn device ->
      %{
        id: device.id,
        name: device.name,
        status: device.status
      }
    end)
    total_devices = length(devices)

    # Get unique device locations
    device_locations = devices
    |> Enum.map(fn device ->
      %{
        latitude: device.latitude,
        longitude: device.longitude
      }
    end)
    |> Enum.uniq()
    |> Enum.filter(fn loc -> loc.latitude != nil and loc.longitude != nil end)

    # Get total sensor count instead of sensor objects
    total_sensors = Atlas.Devices.list_sensors() |> length()

    statistics = %{
      users: users,
      total_users: total_users,
      devices: devices_with_status,
      total_devices: total_devices,
      total_sensors: total_sensors,
      device_locations: device_locations
    }

    message = %{title: nil, body: "Successfully fetched statistics"}

    conn
    |> put_status(:ok)
    |> json(%{data: statistics, message: message})
  end

  # Helper function to determine user status
  defp get_user_status(user) do
    cond do
      user.confirmed_at != nil -> "active"
      true -> "pending"
    end
  end

  # Swagger Implementations
  swagger_path :create do
    post("/users/register")
    summary("Create User")

    description("Signup user")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:CreateUser), "Create New User by passing params", required: true)
    end

    response(200, "Ok", Schema.ref(:users))
  end

  swagger_path :show do
    get("/user/{id}")
    summary("Get user details")

    description("Get user details by passing user id")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :integer, "User ID", required: true)
    end

    response(200, "Ok", Schema.ref(:users))
  end

  swagger_path :get_statistics do
    get("/users/statistics")
    summary("Get User and Device Statistics")
    description("Get detailed statistics about users, devices, and sensors")
    produces("application/json")
    security([%{Bearer: []}])
    response(200, "Ok", Schema.ref(:statistics))
  end

  def swagger_definitions do
    %{
      CreateUser:
        swagger_schema do
          title("Create User")
          description("Signup user")

          properties do
            email(:string, "User email must have the @ sign and no spaces")
            password(:string, "Pasword must be min 12 and max 72")
          end

          example(%{
            email: "admin@admin.com",
            password: "password/123"
          })
        end,
      CreateUserSocially:
        swagger_schema do
          title("Create User with Social Accounts")
          description("Signup user by Social Accounts")

          properties do
            email(:string, "User email must have the @ sign and no spaces")
            first_name(:string, "User first name")
            last_name(:string, "User last name")
            provider(:string, "Social Provider (Google/Apple)")
          end

          example(%{
            email: "admin@admin.com",
            first_name: "User First Name",
            last_name: "User Last Name",
            provider: "google"
          })
        end,
      CreateUserByApple:
        swagger_schema do
          title("Create User with Social Accounts")
          description("Signup user by Social Accounts")

          properties do
            email(:string, "User email must have the @ sign and no spaces")
            apple_identifier(:string, "Apple identifier returned by apple auth")
            provider(:string, "Social Provider (Google/Apple)")
          end

          example(%{
            email: "sudo@appleemail.com",
            apple_identifier: "apple_unique_identifier",
            provider: "google"
          })
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
            provider(:string, "password")
            image_url(:string, "Avatar url")
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
              id: 26,
              inserted_at: "2024-05-20T20:20:37Z",
              password: "2024-05-20T20:20:37Z",
              updated_at: "2024-05-20T20:20:37Z",
              token: "R7-vrW98kLb-CyAKHWeRo8im2wxOdOcTd_pwHAJc9uE=",
              phone_number_primary: "+123456",
              first_name: "First Name",
              last_name: "Last Name",
              provider: "password",
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
        end,
      statistics:
        swagger_schema do
          title("Statistics")
          description("User and device statistics")

          properties do
            users(:array, "List of users with their details")
            total_users(:integer, "Total number of users")
            devices(:array, "List of devices with their status")
            total_devices(:integer, "Total number of devices")
            device_locations(:array, "List of unique device locations")
            total_sensors(:integer, "Total number of sensors")
          end

          example(%{
            data: %{
              users: [
                %{
                  id: 1,
                  email: "user@example.com",
                  created_at: "2024-03-20T20:20:37Z",
                  status: "active"
                }
              ],
              total_users: 1,
              devices: [
                %{
                  id: 1,
                  name: "Device 1",
                  status: "online"
                }
              ],
              total_devices: 1,
              device_locations: ["Location 1", "Location 2"],
              total_sensors: 5
            },
            message: %{
              body: "Successfully fetched statistics",
              title: nil
            }
          })
        end
    }
  end


    def delete_users_and_organizations_with_nil_role(conn, _params) do
      {:ok, message} = Accounts.delete_users_and_organizations_with_nil_role_except_201()
      conn
      |> put_status(:ok)
      |> json(%{
        message: message
      })
    end
end

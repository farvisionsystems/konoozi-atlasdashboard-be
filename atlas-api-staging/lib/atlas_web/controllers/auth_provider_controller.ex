defmodule AtlasWeb.AuthProviderController do
  use AtlasWeb, :controller

  alias Atlas.Accounts.{AuthProvider, AuthProviders}

  def create(%{assigns: %{current_user: nil}} = conn, _auth_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def create(%{assigns: %{current_user: %{id: id}}} = conn, auth_params) do
    auth_params = Map.put(auth_params, "user_id", id)

    case AuthProviders.create_auth_provider(auth_params) do
      {:ok, %AuthProvider{} = auth_provider} ->
        message = %{title: nil, body: "Successfully created Auth Provider"}

        conn
        |> put_status(:created)
        |> render("auth_provider.json", auth_provider: auth_provider, message: message)

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render("error.json", error: error)

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: message)
    end
  end

  # Swagger Implementations
  swagger_path :create do
    post("/auth_provider")
    summary("Create an Auth Provider for existing account")

    description("Create a new login method")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:CreateAuthProvider), "Create New login method by passing params",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:buyers))
  end

  def swagger_definitions do
    %{
      CreateAuthProvider:
        swagger_schema do
          title("Create Login Auth Method")
          description("Create Login Auth Method")

          properties do
            email(:string, "Login Method Email address")
            apple_identifier(:string, "Apple identifier if it's apple login")
            provider(:string, "Login provider")
          end

          example(%{
            email: "buyer@email.com",
            apple_identifier: "XYZ",
            provider: "apple"
          })
        end,
      buyers:
        swagger_schema do
          properties do
            id(:integer, "Provider unique id")
            email(:string, "Auth Provider unique email")
            apple_identifier(:string, "Apple Auth provider unique idetifier")
            provider(:string, "google/apple/password")
            inserted_at(:string, "User inserted at Datetime")
            updated_at(:string, "User updated at Datetime")
          end

          example(%{
            data: %{
              id: 9,
              email: "buyer@email.com",
              provider: "google",
              apple_identifier: "XYZ",
              user_id: 23,
              inserted_at: "2024-06-04T11:45:05Z",
              updated_at: "2024-06-04T11:45:05Z"
            },
            message: %{
              body: "Successfully created auth provider",
              title: "null"
            }
          })
        end
    }
  end
end

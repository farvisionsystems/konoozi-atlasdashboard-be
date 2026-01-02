defmodule AtlasWeb.BuyerController do
  use AtlasWeb, :controller
  alias Atlas.Note
  alias Atlas.{Buyers, Buyer, Repo, Accounts.User, BuyerSearch}
  import Atlas.Buyers, only: [put_flag: 2, put_is_favourite_flag: 2, put_notes: 2]

  def index(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def index(%{assigns: %{current_user: %{id: user_id}}} = conn, _buyer_params) do
    buyers =
      Buyers.get_all_buyers()
      |> put_flag(user_id)
      |> put_is_favourite_flag(user_id)
      |> put_notes(user_id)

    message = %{title: nil, body: "Successfully loaded all application buyers"}

    conn
    |> render("buyers.json", buyers: buyers, message: message)
  end

  def show(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def show(%{assigns: %{current_user: %{id: user_id}}} = conn, %{"id" => id}) do
    case Buyers.get_buyer(id) do
      nil ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: %{message: "Buyer not found"})

      buyer ->
        buyer = buyer |> put_flag(user_id) |> put_is_favourite_flag(user_id) |> put_notes(user_id)
        message = %{title: nil, body: "Successfully fetched buyer"}

        conn
        |> render("buyer_with_user.json", buyer: buyer, message: message)
    end
  end

  def user_buyers(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def user_buyers(%{assigns: %{current_user: %{id: user_id}}} = conn, _buyer_params) do
    buyers =
      Buyers.get_users_buyers(user_id)
      |> put_flag(user_id)
      |> put_is_favourite_flag(user_id)
      |> put_notes(user_id)

    message = %{title: nil, body: "Successfully fetched user's buyers"}

    conn
    |> render("buyers_paginated.json", buyers: buyers, message: message)
  end

  def favourite_buyers(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def favourite_buyers(%{assigns: %{current_user: %{id: user_id}}} = conn, _buyer_params) do
    buyers =
      User.get_users_favourite_buyers(user_id)
      |> Repo.preload(user: [:profile])
      |> put_flag(user_id)
      |> put_is_favourite_flag(user_id)
      |> put_notes(user_id)

    message = %{title: nil, body: "Successfully fetched user's buyers"}

    conn
    |> render("buyers.json", buyers: buyers, message: message)
  end

  def favourite_buyer(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def favourite_buyer(%{assigns: %{current_user: %{id: user_id}}} = conn, %{
        "buyer_id" => buyer_id,
        "is_favourite" => is_favourite
      }) do
    buyer_id = if is_binary(buyer_id), do: String.to_integer(buyer_id), else: buyer_id

    is_favourite =
      if is_binary(is_favourite), do: String.to_atom(is_favourite), else: is_favourite

    case User.update_buyers_favourite(user_id, buyer_id, is_favourite) do
      {:ok, _user} ->
        message =
          if is_favourite do
            %{title: nil, body: "Successfully favourited buyers"}
          else
            %{title: nil, body: "Successfully unfavourited buyers"}
          end

        buyer =
          Buyers.get_buyer(buyer_id)
          |> Repo.preload(user: [:profile])
          |> put_flag(user_id)
          |> put_is_favourite_flag(user_id)
          |> put_notes(user_id)

        conn
        |> render("buyer.json", buyer: buyer, message: message)

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render("error.json", error: error)

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: "Bad Request")
    end
  end

  def other_buyers(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def other_buyers(%{assigns: %{current_user: %{id: id}}} = conn, _buyer_params) do
    buyers =
      Buyers.get_other_buyers(id) |> put_flag(id) |> put_is_favourite_flag(id) |> put_notes(id)

    message = %{title: nil, body: "Successfully fetched other buyers"}

    conn
    |> render("buyers.json", buyers: buyers, message: message)
  end

  def create(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def create(%{assigns: %{current_user: %{id: id}}} = conn, buyer_params) do
    buyer_params = Map.put(buyer_params, "user_id", id)
    buyer_locations_of_interest = Map.get(buyer_params, "buyer_locations_of_interest", [])

    case Buyers.create_buyers(buyer_params) do
      {:ok, %Buyer{} = buyer} ->
        # Fetch user IDs with matching zip codes
        matching_user_ids =
          Buyers.get_user_ids_by_zip_codes(buyer_locations_of_interest)
          |> Enum.reject(fn user_id -> user_id == id end)


        buyer =
          buyer
          |> Repo.preload([:buyer_need, user: [:profile]])
          |> put_flag(id)
          |> put_is_favourite_flag(id)
          |> put_notes(id)

        # Send notifications asynchronously
        Task.start(fn ->
          Atlas.MobileNotifier.send_push_notification_by_user_ids(
            matching_user_ids,
            "BuyerBoard",
            "New Buyer Created in Your Area!",
            "A new buyer has shown interest in your location.",
            buyer
          )
        end)

        message = %{title: nil, body: "Successfully created buyer"}

        conn
        |> put_status(:created)
        |> render("buyer.json", buyer: buyer, message: message)

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render("error.json", error: error)

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", error: "Bad Request")
    end
  end

  def update(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def update(%{assigns: %{current_user: %{id: id}}} = conn, %{"id" => buyer_id} = buyer_params) do
    if Buyers.my_buyer?(id, buyer_id) do
      buyer_params = Map.put(buyer_params, "user_id", id)

      with %Buyer{} = buyer <- Repo.get(Buyer, buyer_id) |> Repo.preload([:buyer_need]),
           {:ok, %Buyer{} = buyer} <- Buyers.edit_buyers(buyer, buyer_params) do
        buyer =
          buyer
          |> Repo.preload([:buyer_need, user: [:profile]])
          |> put_flag(id)
          |> put_is_favourite_flag(id)
          |> put_notes(id)

        message = %{title: nil, body: "Successfully updated buyer"}

        conn
        |> put_status(:created)
        |> render("buyer.json", buyer: buyer, message: message)
      else
        {:error, %Ecto.Changeset{} = changeset} ->
          error = translate_errors(changeset)

          conn
          |> put_status(:bad_request)
          |> render("error.json", error: error)

        _ ->
          conn
          |> put_status(:bad_request)
          |> render("error.json", error: "Buyer Not found")
      end
    else
      conn
      |> put_status(:bad_request)
      |> render("error.json", error: "You can't edit other buyers")
    end
  end

  def filtered_buyers(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def filtered_buyers(
        %{assigns: %{current_user: %{id: id}}} = conn,
        %{"filters" => filters} = params
      ) do
    # Default page and page_size to 1 and 10 if not provided
    page = Map.get(params, "page", "1")
    page_size = Map.get(params, "page_size", "100")

    # Ensure sort_options is present (default to empty map if missing)
    sort_options = Map.get(filters, "sort_options", %{})

    pagination =
      Buyers.get_all_buyers_with_filters(
        %{
          "sort_options" => sort_options,
          "filters" => filters,
          "page" => page,
          "page_size" => page_size
        },
        id
      )

    buyers =
      pagination.entries
      |> put_flag(id)
      |> put_is_favourite_flag(id)
      |> put_notes(id)

    message = %{title: nil, body: "Successfully loaded all application buyers"}

    conn
    |> render("buyers_paginated.json", buyers: buyers, message: message, pagination: pagination)
  end

  def search_buyers(%{assigns: %{current_user: nil}} = conn, _buyer_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def search_buyers(%{assigns: %{current_user: %{id: id}}} = conn, %{"zip_code" => zip_code}) do
    buyers =
      BuyerSearch.search_buyers_by_zip_code(zip_code)
      |> put_flag(id)
      |> put_is_favourite_flag(id)
      |> put_notes(id)

    message = %{title: nil, body: "Successfully searched buyers"}

    conn
    |> render("buyers.json", buyers: buyers, message: message)
  end

  def delete_user(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def delete_user(%{assigns: %{current_user: %{id: user_id}}} = conn, _params) do
    user_email = Atlas.Accounts.get_user_by_id(user_id)
    Atlas.Accounts.UserNotifier.deliver_account_deleted_email(user_email)

    case Atlas.Accounts.deleteAccount(user_id) do
      {:ok, _result} ->
        message = %{title: nil, body: "User account successfully deleted"}

        conn
        |> put_status(:ok)
        |> render("success.json", message: message)

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> render("error.json", error: %{message: "Error deleting account"})
    end
  end

  # Swagger Implementations
  swagger_path :index do
    get("/buyers")
    description("List of whole application Buyers")
    security([%{Bearer: []}])
    response(code(:ok), Schema.ref(:ListAllBuyers))
  end

  swagger_path :filtered_buyers do
    post("/filtered_buyers")
    description("List of filtered whole application Buyers")
    security([%{Bearer: []}])

    parameters do
      body(
        :body,
        Schema.ref(:ListAllFilteredBuyers),
        "List of all filtered buyers by  passing filters",
        required: true
      )
    end
  end

  swagger_path :search_buyers do
    post("/search_buyers/{zip_code}")
    description("List of buyers by searching by zip code")
    security([%{Bearer: []}])

    parameters do
      zip_code(:path, :integer, "Zip Code", required: true)
    end
  end

  swagger_path :user_buyers do
    get("/user_buyers")
    description("List of Buyers of logged in user")
    security([%{Bearer: []}])
    response(code(:ok), Schema.ref(:ListBuyers))
  end

  swagger_path :other_buyers do
    get("/other_buyers")
    description("List of Other Buyers which doesn't belong to logged in user")
    security([%{Bearer: []}])
    response(code(:ok), Schema.ref(:ListOtherBuyers))
  end

  swagger_path :favourite_buyers do
    get("/favourite_buyers")
    description("List of All Favourite Buyers which belongs to logged in user")
    security([%{Bearer: []}])
    response(code(:ok), Schema.ref(:ListFavouriteBuyers))
  end

  swagger_path :show do
    get("/buyer/{id}")
    description("List of whole application Buyers")
    security([%{Bearer: []}])
    response(code(:ok), Schema.ref(:GetBuyer))

    parameters do
      id(:path, :integer, "Buyer ID", required: true)
    end
  end

  swagger_path :create do
    post("/buyer")
    summary("Create a Buyer for user")

    description("Create a Buyer")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      body(:body, Schema.ref(:CreateBuyer), "Create New Buyer by passing params", required: true)
    end

    response(200, "Ok", Schema.ref(:buyers))
  end

  swagger_path :update do
    put("/buyer/{id}")
    summary("Updates a buyer")
    description("Updates the details of a specific buyer")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :integer, "Buyer ID", required: true)
      body(:body, Schema.ref(:UpdateBuyer), "Buyer update parameters", required: true)
    end

    response(200, "Buyer updated successfully", Schema.ref(:buyers))
    response(404, "Buyer not found")
  end

  swagger_path :favourite_buyer do
    post("/favourite_buyer/{id}")
    summary("Make buyer favourite")
    description("Any user can make a buyer favourite")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :integer, "Buyer ID", required: true)

      body(:body, Schema.ref(:FavouriteBuyer), "Make  buyer favourite paramenters", required: true)
    end

    response(200, "Marked Buyer favourite/unfavourite successfully", Schema.ref(:buyers))
    response(404, "Buyer not found")
  end

  def swagger_definitions do
    %{
      ListAllBuyers:
        swagger_schema do
          title("List all Buyers")
          description("List All available Buyers")
        end,
      ListAllFilteredBuyers:
        swagger_schema do
          title("List all Buyers")
          description("List All available Buyers")

          properties do
            sort_options(:map, "Sort by Options")
          end

          example(%{
            sort_options: %{
              buyer_locations_of_interest: "asc, desc, one of them",
              inserted_at: "desc, asc, one of them"
            },
            filters: %{
              purchase_type: "purchase, lease, one of them",
              property_type:
                " single_family_house, townhouse, condo, apartment, multi_family_house, mobile, one of them",
              financial_status:
                "pre_qualified, pre_approved, all_cash, undetermined, one of them",
              min_bedrooms: 2,
              min_bathrooms: 1.5,
              min_area: 1500,
              search_zip_code: "12345"
            }
          })
        end,
      ListBuyers:
        swagger_schema do
          title("List Buyers")
          description("List Buyers of current logged in user")
        end,
      ListOtherBuyers:
        swagger_schema do
          title("List Other Buyers")
          description("List Other Buyers which aren't belong to current logged in user")
        end,
      ListFavouriteBuyers:
        swagger_schema do
          title("List All Favourite Buyers")
          description("List All Favourite Buyers which belongs to current logged in user")
        end,
      FavouriteBuyer:
        swagger_schema do
          title("Favourite Buyer")
          description("Favourite Buyer which belongs to current logged in user")

          properties do
            is_favourite(:string, "Is favourite option for buyer")
          end

          example(%{
            is_favourite: "true"
          })
        end,
      GetBuyer:
        swagger_schema do
          title("Get Buyer with user's details")
          description("Get Buyer with user's details by it's id")
        end,
      CreateBuyer:
        swagger_schema do
          title("Create Buyer")
          description("Create Buyer")

          properties do
            first_name(:string, "Buyer's first name")
            last_name(:string, "Buyer's last name")
            image_url(:string, "Buyer's image url")
            email(:string, "Buyer's Email address")
            notes(:string, "Favourite Buyer's Notes")
            primary_phone_number(:string, "Buyer's primary phone number")
            buyer_locations_of_interest(:list, "Buyer's locations")
            additional_requests(:string, "Buyer's additional desires")
            is_favourite(:boolean, "Buyer is favourite/not_favourite of user")

            buyer_expiration_date(:string, "Datetime of video file last modification",
              format: "date-time",
              "x-nullable": true
            )

            purchase_type(:string, "Buyer's need Purchase type must be purchase/lease")

            property_type(
              :string,
              "Buyer's need Property Type must be single_family_house/townhouse/condo/apartment/multi_family_house/mobile"
            )

            financial_status(
              :string,
              "Buyer's need Financial status must be pre_qualified/pre_approved/all_cash/undeterminded"
            )

            budget_upto(:string, "Buyer's Budget upto")
            min_bedrooms(:string, "Buyer's need of minimun bedrooms")
            min_bathrooms(:string, "Buyer's need of minimun bathrooms")
            min_area(:string, "Buyer's need of minimun area")
          end

          example(%{
            email: "buyer@email.com",
            first_name: "First",
            last_name: "Last",
            image_url: "/image.png",
            primary_phone_number: "+12345",
            buyer_locations_of_interest: ["Location1", "Location2", "Location3"],
            additional_requests: ["Desire1", "Desire2", "Desire3"],
            note: "This is my favourite buyer and I am note for it",
            is_favourite: false,
            buyer_expiration_date: "2024-06-04 11:08:48Z",
            buyer_need: %{
              purchase_type: "purchase, lease, one of them",
              property_type:
                " single_family_house, townhouse, condo, apartment, multi_family_house, mobile, one of them",
              financial_status:
                "pre_qualified, pre_approved, all_cash, undetermined, one of them",
              budget_upto: "900k",
              min_bedrooms: "2",
              min_bathrooms: "1.5",
              min_area: "1.5k"
            }
          })
        end,
      UpdateBuyer:
        swagger_schema do
          title("Updated specific buyer")
          description("Updated specific buyer")

          properties do
            first_name(:string, "Buyer's first name")
            last_name(:string, "Buyer's last name")
            image_url(:string, "Buyer's image url")
            email(:string, "Buyer's Email address")
            notes(:string, "Favourite Buyer's Notes")
            primary_phone_number(:string, "Buyer's primary phone number")
            buyer_locations_of_interest(:list, "Buyer's locations")
            additional_requests(:string, "Buyer's additional desires")
            is_favourite(:boolean, "Buyer is favourite/not_favourite of user")

            buyer_expiration_date(:string, "Datetime of video file last modification",
              format: "date-time",
              "x-nullable": true
            )

            purchase_type(:string, "Buyer's need Purchase type must be purchase/lease")

            property_type(
              :string,
              "Buyer's need Property Type must be single_family_house/townhouse/condo/apartment/multi_family_house/mobile"
            )

            financial_status(
              :string,
              "Buyer's need Financial status must be pre_qualified/pre_approved/all_cash/undeterminded"
            )

            budget_upto(:string, "Buyer's Budget upto")
            min_bedrooms(:string, "Buyer's need of minimun bedrooms")
            min_bathrooms(:string, "Buyer's need of minimun bathrooms")
            min_area(:string, "Buyer's need of minimun area")
          end

          example(%{
            email: "buyer@email.com",
            first_name: "First",
            last_name: "Last",
            image_url: "/image.png",
            primary_phone_number: "+12345",
            buyer_locations_of_interest: ["Location1", "Location2", "Location3"],
            additional_requests: ["Desire1", "Desire2", "Desire3"],
            note: "This is my favourite buyer and I am note for it",
            buyer_expiration_date: "2024-06-04 11:08:48Z",
            is_favourite: false,
            buyer_need: %{
              purchase_type: "purchase, lease, one of them",
              property_type:
                " single_family_house, townhouse, condo, apartment, multi_family_house, mobile, one of them",
              financial_status:
                "pre_qualified, pre_approved, all_cash, undetermined, one of them",
              budget_upto: "900k",
              min_bedrooms: "2",
              min_bathrooms: "1.5",
              min_area: "1.5k"
            }
          })
        end,
      buyers:
        swagger_schema do
          properties do
            id(:integer, "User unique id")
            first_name(:string, "Buyer's first name")
            last_name(:string, "Buyer's last name")
            image_url(:string, "Buyer's image url")
            email(:string, "Buyer's Email address")
            notes(:string, "Favourite Buyer's Notes")
            primary_phone_number(:string, "Buyer's primary phone number")
            buyer_locations_of_interest(:list, "Buyer's locations list")
            additional_requests(:list, "Buyer's additional desires list")

            buyer_expiration_date(:string, "Datetime of video file last modification",
              format: "date-time",
              "x-nullable": true
            )

            purchase_type(:string, "Buyer's need Purchase type must be purchase/lease")

            property_type(
              :string,
              "Buyer's need Property Type must be single_family_house/townhouse/condo/apartment/multi_family_house/mobile"
            )

            financial_status(
              :string,
              "Buyer's need Financial status must be pre_qualified/pre_approved/all_cash/undeterminded"
            )

            budget_upto(:string, "Buyer's Budget upto")
            min_bedrooms(:string, "Buyer's need of minimun bedrooms")
            min_bathrooms(:string, "Buyer's need of minimun bathrooms")
            min_area(:string, "Buyer's need of minimun area")
            inserted_at(:string, "User inserted at Datetime")
            updated_at(:string, "User updated at Datetime")
          end

          example(%{
            data: %{
              additional_requests: [
                "Desire1",
                "Desire2",
                "Desire3"
              ],
              buyer_expiration_date: "2024-06-04T11:08:48Z",
              buyer_locations_of_interest: [
                "Location1",
                "Location2",
                "Location3"
              ],
              buyer_need: %{
                id: 4,
                purchase_type: "purchase",
                property_type: "single_family_house",
                financial_status: "pre_qualified",
                budget_upto: "900k",
                min_bedrooms: "2",
                min_bathrooms: "1.5",
                min_area: "1.5k",
                buyer_id: 9,
                inserted_at: "2024-06-04T11:45:05Z",
                updated_at: "2024-06-04T11:45:05Z"
              },
              email: "buyer@email.com",
              note: "This is my favourite buyer and I am note for it",
              first_name: "First",
              id: 9,
              image_url: "/image.png",
              inserted_at: "2024-06-04T11:45:05Z",
              last_name: "Last",
              primary_phone_number: "+12345",
              updated_at: "2024-06-04T11:45:05Z",
              user_id: 23
            },
            message: %{
              body: "Successfully created buyer",
              title: "null"
            }
          })
        end
    }
  end
end

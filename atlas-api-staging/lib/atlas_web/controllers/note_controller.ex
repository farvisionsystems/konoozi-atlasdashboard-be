defmodule AtlasWeb.NoteController do
  use AtlasWeb, :controller
  alias Atlas.{Repo, Note, Buyer}
  import Atlas.Buyers, only: [put_flag: 2, put_is_favourite_flag: 2, put_notes: 2]

  def create(%{assigns: %{current_user: nil}} = conn, _user_params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def create(%{assigns: %{current_user: %{id: user_id}}} = conn, note_params) do
    note_params = Map.put(note_params, "user_id", user_id)
    changeset = Note.changeset(%Note{}, note_params)

    with {:ok, _} <- Note.delete_note_if_exists(note_params["buyer_id"], user_id),
         {:ok, note} <- Repo.insert(changeset) do
      buyer =
        Repo.get(Buyer, note.buyer_id)
        |> Repo.preload([:buyer_need, user: [:profile]])
        |> put_flag(user_id)
        |> put_is_favourite_flag(user_id)
        |> put_notes(user_id)

      message = %{title: nil, body: "Successfully added note"}

      conn
      |> put_status(:created)
      |> render("show.json", %{buyer: buyer, message: message})
    else
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

  swagger_path :create do
    post("/buyer_note/{buyer_id}")
    summary("Create a Note for favourited Buyers")

    description("Add note to buyer")

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      buyer_id(:path, :integer, "Buyer ID", required: true)
      body(:body, Schema.ref(:AddNote), "Buyer update parameters", required: true)
    end

    response(200, "Ok", Schema.ref(:buyers))
  end

  def swagger_definitions do
    %{
      AddNote:
        swagger_schema do
          title("Add note to buyer")
          description("User can add a note to his favourited buyers")

          properties do
            content(:string, "Note content")
          end

          example(%{
            content: "This is my favourote buyer"
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
                purchase_type: "lease",
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

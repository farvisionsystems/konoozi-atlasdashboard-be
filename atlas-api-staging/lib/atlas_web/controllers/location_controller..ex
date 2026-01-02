defmodule AtlasWeb.LocationController do
  use AtlasWeb, :controller
  alias Atlas.{Location, Repo, LocationSorter}

  def index(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def index(conn, _params) do
    locations = Location.all()
    message = %{title: nil, body: "Successfully loaded all USA Locations"}

    conn
    |> render("locations.json", locations: locations, message: message)
  end

  def show(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def show(conn, %{"zip_code" => zip_code}) do
    case Repo.get_by(Location, zip_code: zip_code) do
      nil ->
        conn
        |> put_status(:bad_request)
        |> render("error.json",
          error: %{message: "Zip code #{zip_code} doesn't match any location in USA"}
        )

      location ->
        message = %{title: nil, body: "Successfully loaded USA Locations by zip code #{zip_code}"}

        conn
        |> render("location.json", location: location, message: message)
    end
  end

  def state_index(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def state_index(conn, _params) do
    states = Location.all_states()
    message = %{title: nil, body: "Successfully loaded all USA States"}

    conn
    |> render("states.json", states: states, message: message)
  end

  def buyer_locations(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:bad_request)
    |> render("error.json", error: %{message: "Unauthenticated"})
  end

  def buyer_locations(conn, params) do
    locations = LocationSorter.list_sorted_locations(params)
    message = %{title: nil, body: "Successfully loaded USA Locations where Buyers exist"}

    conn
    |> render("locations.json", locations: locations, message: message)
  end

  # Swagger Implementations
  swagger_path :index do
    get("/locations")
    description("List of whole USA Locations")
    security([%{Bearer: []}])
    response(code(:ok), Schema.ref(:ListAllLocations))
  end

  swagger_path :state_index do
    get("/states")
    description("List of all USA states")
    security([%{Bearer: []}])
    response(code(:ok), Schema.ref(:ListAllStates))
  end

  swagger_path :buyer_locations do
    post("/buyer_locations")
    description("List of all Locations where our buyer's exists")
    security([%{Bearer: []}])

    parameters do
      zip_code(:body, :integer, "Zip Code", required: false)
    end

    response(code(:ok), Schema.ref(:ListBuyerLocations))
  end

  swagger_path :show do
    get("/location/{zip_code}")
    description("Get a location by there zip code")
    security([%{Bearer: []}])
    response(code(:ok), Schema.ref(:GetLocation))

    parameters do
      zip_code(:path, :integer, "Zip Code", required: true)
    end
  end

  def swagger_definitions do
    %{
      ListAllLocations:
        swagger_schema do
          title("List all Locations")
          description("List all USA Locations")
        end,
      ListBuyerLocations:
        swagger_schema do
          title("List all Locations where our buyer exists")
          description("List all USA Locations")
        end,
      ListAllStates:
        swagger_schema do
          title("List all States")
          description("List all USA States")
        end,
      GetLocation:
        swagger_schema do
          title("Get Location")
          description("Get a location by a zip code")
        end
    }
  end
end

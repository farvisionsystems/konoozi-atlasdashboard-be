defmodule Atlas.LocationSorter do
  @moduledoc """
  Sort Locations by distance where our Buyers exist.
  """
  import Ecto.Query, only: [from: 2]
  alias Atlas.{Repo, Location, Buyer}

  def degrees_to_radians(degrees), do: degrees * :math.pi() / 180

  def haversine_distance({lat1, lon1}, {lat2, lon2}) do
    r = 6371.0
    dlat = degrees_to_radians(lat2 - lat1)
    dlon = degrees_to_radians(lon2 - lon1)

    a =
      :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(degrees_to_radians(lat1)) * :math.cos(degrees_to_radians(lat2)) *
          :math.sin(dlon / 2) * :math.sin(dlon / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    r * c
  end

  def get_lat_long(zip_code) do
    Repo.get_by(Location, zip_code: zip_code)
    |> case do
      nil -> nil
      location -> {location.latitude, location.longitude}
    end
  end

  def extract_zip_codes_from_buyers do
    from(b in Buyer,
      where: b.buyer_expiration_date >= ^DateTime.utc_now(),
      select: b.buyer_locations_of_interest
    )
    |> Repo.all()
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.map(fn location ->
      case Regex.run(~r/^\d{5}/, location) do
        [zip_code] -> zip_code
        _ -> nil
      end
    end)
  end

  def fetch_buyer_locations_with_coords do
    extract_zip_codes_from_buyers()
    |> Enum.reduce([], fn zip_code, acc ->
      case get_lat_long(zip_code) do
        nil -> acc
        coords -> [{zip_code, coords} | acc]
      end
    end)
    |> Enum.reverse()
  end

  def sort_locations_by_distance(user_coords, locations_with_coords) do
    locations_with_coords
    |> Enum.map(fn {zip_code, coords} ->
      distance = haversine_distance(user_coords || {0, 0}, coords)
      {zip_code, distance}
    end)
    |> Enum.sort_by(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  def list_sorted_locations(params) do
    page = Map.get(params, "page", 1)
    page_size = Map.get(params, "page_size", 20)

    search_param = Map.get(params, "zip_code") || Map.get(params, "city_name")
    zip_codes_from_buyers = extract_zip_codes_from_buyers()

    base_query =
      from l in Location, where: l.zip_code in ^zip_codes_from_buyers, order_by: l.zip_code

    query =
      if search_param && String.length(search_param) > 0 do
        from l in base_query,
          where:
            ilike(l.zip_code, ^"%#{search_param}%") or ilike(l.city_name, ^"%#{search_param}%")
      else
        base_query
      end

    # Apply pagination to the query
    Repo.paginate(query, page: page, page_size: page_size)
  end

  def fetch_locations_record(list_of_zip_codes, page_number, page_size) do
    query =
      from l in Location,
        where: l.zip_code in ^list_of_zip_codes,
        order_by: l.zip_code

    Repo.paginate(query, page: page_number, page_size: page_size)
  end
end

defmodule Atlas.BuyerSearch do
  import Ecto.Query
  alias Atlas.{Buyer, Repo, Location}

  @radius_in_miles 50.0

  def search_buyers_by_zip_code(zip_code) do
    search_zip_code = "%" <> zip_code <> "%"

    # Fetch buyer structs with the exact zip code
    exact_zip_code_buyers =
      from(b in Buyer,
        where: fragment("(buyer_locations_of_interest::TEXT) LIKE ?", ^search_zip_code),
        select: %{id: b.id, buyer_locations_of_interest: b.buyer_locations_of_interest}
      )
      |> Repo.all()

    # Fetch adjacent zip codes
    adjacent_zip_codes = get_adjacent_zip_codes(zip_code)

    # Fetch buyer structs with adjacent zip codes using parallel processing
    adjacent_zip_code_buyers =
      adjacent_zip_codes
      |> Task.async_stream(
        fn zip ->
          search_zip_code = "%" <> zip <> "%"

          from(b in Buyer,
            where: fragment("(buyer_locations_of_interest::TEXT) LIKE ?", ^search_zip_code),
            select: %{id: b.id, buyer_locations_of_interest: b.buyer_locations_of_interest}
          )
          |> Repo.all()
        end,
        max_concurrency: 8
      )
      |> Enum.map(fn
        # Extract result from {:ok, result}
        {:ok, result} -> result
        # Handle errors (optional)
        {:error, _reason} -> []
      end)
      |> List.flatten()

    # Combine results and apply custom sorter
    combined_buyers = exact_zip_code_buyers ++ adjacent_zip_code_buyers

    sorted_buyers =
      Enum.uniq(combined_buyers)
      |> Enum.sort(&custom_sorter(&1, &2, zip_code, adjacent_zip_codes))

    sorted_buyers
  end

  def custom_sorter(buyer1, buyer2, zip_code, adjacent_zip_codes) do
    rank1 = rank_buyer(buyer1, zip_code, adjacent_zip_codes)
    rank2 = rank_buyer(buyer2, zip_code, adjacent_zip_codes)

    cond do
      rank1 < rank2 -> true
      rank1 > rank2 -> false
      # Sort by ID if ranks are equal
      true -> buyer1.id < buyer2.id
    end
  end

  defp rank_buyer(buyer, zip_code, adjacent_zip_codes) do
    case Enum.find(buyer.buyer_locations_of_interest, fn loc ->
           String.contains?(loc, zip_code)
         end) do
      nil ->
        case Enum.find(buyer.buyer_locations_of_interest, fn loc ->
               Enum.any?(adjacent_zip_codes, &String.contains?(loc, &1))
             end) do
          nil -> 2
          _ -> 1
        end

      _ ->
        0
    end
  end

  def get_adjacent_zip_codes(zip_code) do
    with %{latitude: lat, longitude: lon} <- get_zip_code_coordinates(zip_code) do
      query =
        from(l in Location,
          where:
            fragment(
              "ST_DistanceSphere(ST_SetSRID(ST_MakePoint(CAST(? AS DOUBLE PRECISION), CAST(? AS DOUBLE PRECISION)), 4326), ST_SetSRID(ST_MakePoint(?, ?), 4326)) <= ?",
              l.longitude,
              l.latitude,
              ^lon,
              ^lat,
              ^@radius_in_miles * 1609.34
            ),
          order_by: fragment("CASE WHEN ? = ? THEN 0 ELSE 1 END", l.zip_code, ^zip_code),
          select: l.zip_code
        )

      Repo.all(query)
    else
      _ -> []
    end
  end

  defp get_zip_code_coordinates(zip_code) do
    Repo.get_by(Location, zip_code: zip_code)
  end
end

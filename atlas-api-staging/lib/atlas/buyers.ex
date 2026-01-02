defmodule Atlas.Buyers do
  @moduledoc """
  Buyer context.
  """
  @radius_in_miles 100.0

  import Ecto.Query, warn: false
  alias Atlas.{Repo, Buyer, Accounts.User, Note, Location, Profile, TimezoneAdjuster}

  def create_buyers(attrs \\ %{}) do
    timezone_offset = Map.get(attrs, "timezone_offset")

    %Buyer{}
    |> Buyer.changeset(attrs)
    # |> TimezoneAdjuster.adjust_datetime(timezone_offset, [:inserted_at, :updated_at])
    |> Repo.insert()
  end

  def edit_buyers(buyer, attrs \\ %{}) do
    buyer
    |> Buyer.changeset(attrs)
    |> Repo.update()
  end

  def get_user_ids_by_zip_codes(zip_codes) do
    from(p in Profile,
      where: p.brokerage_zip_code in ^zip_codes,
      select: p.user_id
    )
    |> Repo.all()
  end

  def get_buyer(id), do: Repo.get(Buyer, id) |> Repo.preload([:buyer_need, user: [:profile]])

  #  def get_all_buyers(), do: Repo.all(Buyer) |> Repo.preload([:buyer_need, :user])
  def get_all_buyers() do
    from(b in Buyer,
      where: is_nil(b.buyer_expiration_date) or b.buyer_expiration_date > ^DateTime.utc_now()
    )
    |> Repo.all()
    |> Repo.preload([:buyer_need, user: [:profile]])
  end

  def get_users_buyers(id) do
    from(b in Buyer,
      where: b.user_id == ^id
    )
    |> Repo.all()
    |> Repo.preload([:buyer_need, user: [:profile]])
  end

  def get_other_buyers(id) do
    from(b in Buyer,
      where:
        b.user_id != ^id and
          (is_nil(b.buyer_expiration_date) or b.buyer_expiration_date > ^DateTime.utc_now())
    )
    |> Repo.all()
    |> Repo.preload([:buyer_need, user: [:profile]])
  end

  def order_by_params(params) do
    Enum.map(params, fn {field, direction} ->
      field_atom = String.to_existing_atom(field)
      direction_atom = String.to_existing_atom(direction)

      filter_order_by(field_atom, direction_atom)
    end)
    |> List.flatten()
  end

  def get_all_buyers_with_filters(
        %{
          "sort_options" => sort_options,
          "filters" => filters,
          "page" => page,
          "page_size" => page_size
        },
        current_user_id
      ) do
    hide_my_buyers = Map.get(filters, "hide_my_buyers", false)
    current_user_zip_code = Map.get(filters, "search_zip_code", "")
    current_user_zip_code_search = "%" <> current_user_zip_code <> "%"

    # Start query for buyers
    query =
      from(b in Buyer,
        left_join: buyer_needs in assoc(b, :buyer_need),
        where: ^filters_where(filters),
        order_by: [
          # 1. Prioritize buyers created by the current user, then zip code relevance, then insertion time
          desc: b.user_id == ^current_user_id,
          desc:
            fragment(
              "? LIKE ANY(?::TEXT[])",
              ^current_user_zip_code_search,
              b.buyer_locations_of_interest
            ),
          desc: b.inserted_at
        ]
      )

    # Apply the hide_my_buyers filter if it's set to true
    query =
      if hide_my_buyers do
        from(b in query, where: b.user_id != ^current_user_id)
      else
        query
      end

    # If search_zip_code is provided, apply zip code filtering
    query =
      if Map.get(filters, "search_zip_code") not in [nil, ""] do
        zip_code = Map.get(filters, "search_zip_code")
        search_zip_code = "%" <> zip_code <> "%"

        from(q in query,
          where: fragment("(buyer_locations_of_interest::TEXT) LIKE ?", ^search_zip_code)
        )
      else
        query
      end

    # Paginate the query
    paginated_results =
      query
      |> Repo.paginate(page: page, page_size: page_size)

    # Preload associations after paginating
    buyers =
      paginated_results.entries
      |> Repo.preload([:buyer_need, user: [:profile]])

    # Return the paginated results with the preloaded associations
    %Scrivener.Page{paginated_results | entries: buyers}
  end

  def filter_order_by(column, order) do
    [{order, dynamic([buyer], field(buyer, ^column))}]
  end

  defp filters_where(opts) do
    Enum.reduce(opts, dynamic(true), fn
      {type, value}, dynamic
      when type in ["purchase_type", "property_type", "financial_status"] ->
        # Ensure value is a list of strings
        value_list =
          case value do
            list when is_list(list) ->
              list

            value when is_binary(value) ->
              String.split(value, ",", trim: true) |> Enum.map(&String.trim/1)

            _ ->
              []
          end

        dynamic(
          [buyer, buyer_needs],
          ^dynamic and field(buyer_needs, ^String.to_existing_atom(type)) in ^value_list
        )

      {type, value}, dynamic when type in ["min_bedrooms", "min_bathrooms", "min_area"] ->
        # Parse the value to a float
        number_value =
          case value do
            value when is_integer(value) or is_float(value) ->
              value

            value when is_binary(value) ->
              value
              |> String.trim()
              |> parse_number()

            _ ->
              nil
          end

        if number_value != nil do
          dynamic(
            [buyer, buyer_needs],
            ^dynamic and field(buyer_needs, ^String.to_existing_atom(type)) >= ^number_value
          )
        else
          dynamic
        end

      {_, _}, dynamic ->
        # Not a where parameter
        dynamic
    end)
  end

  defp parse_number(value) do
    case Float.parse(value) do
      {float_value, ""} ->
        float_value

      _ ->
        case Integer.parse(value) do
          {int_value, ""} -> int_value
          _ -> nil
        end
    end
  end

  #  defp filters_where(opts) do
  #    Enum.reduce(opts, dynamic(true), fn
  #      {type, value}, dynamic
  #      when type in [
  #        "purchase_type",
  #        "property_type",
  #        "financial_status",
  #        "min_bedrooms",
  #        "min_bathrooms",
  #        "min_area"
  #      ] ->
  #        value_list = String.split(value, ",", trim: true) |> Enum.map(&String.trim/1)
  #
  #        dynamic(
  #          [buyer, buyer_needs],
  #          ^dynamic and field(buyer_needs, ^String.to_existing_atom(type)) in ^value_list
  #        )
  #
  #      {_, _}, dynamic ->
  #        # Not a where parameter
  #        dynamic
  #    end)
  #  end

  def put_flag(data, user_id) when is_list(data) do
    Enum.map(data, fn buyer ->
      put_flag(buyer, user_id)
    end)
  end

  def put_flag(buyer, user_id) do
    if Repo.preload(buyer, :user).user.id == user_id do
      buyer |> Map.put(:my_buyer, true)
    else
      buyer |> Map.put(:my_buyer, false)
    end
  end

  def put_is_favourite_flag(data, user_id) when is_list(data) do
    Enum.map(data, fn buyer ->
      put_is_favourite_flag(buyer, user_id)
    end)
  end

  def put_is_favourite_flag(buyer, user_id) do
    if Enum.member?(Repo.get(User, user_id).favourite_buyers, buyer.id) do
      buyer |> Map.put(:is_favourite, true)
    else
      buyer |> Map.put(:is_favourite, false)
    end
  end

  def put_notes(data, user_id) when is_list(data) do
    Enum.map(data, fn buyer ->
      put_notes(buyer, user_id)
    end)
  end

  def put_notes(buyer, user_id) do
    case Repo.get_by(Note, user_id: user_id, buyer_id: buyer.id) do
      nil ->
        buyer |> Map.put(:note, nil)

      %Note{content: content} ->
        buyer |> Map.put(:note, content)
    end
  end

  def my_buyer?(user_id, buyer_id) do
    from(b in Buyer,
      where: b.id == ^buyer_id and b.user_id == ^user_id
    )
    |> Repo.exists?()
  end
end

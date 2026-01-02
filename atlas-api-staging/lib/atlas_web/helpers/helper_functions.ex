defmodule AtlasWeb.Helpers.HelperFunctions do
  @moduledoc """
  Helper Functions
  """
  def struct_into_map(struct) when is_struct(struct) do
    keys = [:__meta__]

    Map.from_struct(struct)
    |> Map.drop(keys)
    |> struct_into_map()
  end

  def struct_into_map(list) when is_list(list) do
    Enum.map(list, fn x -> struct_into_map(x) end)
  end

  def struct_into_map(map) do
    keys = [:__meta__]

    Enum.reduce(map, %{}, fn
      {key, %Ecto.Association.NotLoaded{}}, acc ->
        Map.put(acc, key, nil)

      {key, val}, acc when val.__struct__ in [DateTime, NaiveDateTime, Date, Time, Decimal] ->
        Map.put(acc, key, val)

      {key, val}, acc when is_struct(val) ->
        Map.put(acc, key, struct_into_map(Map.from_struct(val) |> Map.drop(keys)))

      {key, val}, acc when is_list(val) ->
        Map.put(acc, key, Enum.map(val, fn x -> struct_into_map(x) end))

      {key, val}, acc when is_map(val) ->
        Map.put(acc, key, struct_into_map(val))

      {key, val}, acc ->
        Map.put(acc, key, val)
    end)
  end
end

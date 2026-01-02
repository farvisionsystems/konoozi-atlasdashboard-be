defmodule AtlasWeb.Utils do
  @doc """
  Converts string map keys to atoms.
  Only converts known/safe keys to prevent atom table overflow.
  """
  def atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {safe_atom_from_string(key), value} end)
  end

  # Convert string to existing atom only if it already exists
  defp safe_atom_from_string(string) when is_binary(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError -> string
  end
end

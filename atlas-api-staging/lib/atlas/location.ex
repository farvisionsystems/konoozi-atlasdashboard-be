defmodule Atlas.Location do
  @moduledoc "USA locations"

  use Ecto.Schema
  alias Atlas.{Repo, Buyer}

  import Ecto.Query

  @derive {Jason.Encoder,
           only: [
             :zip_code,
             :city_name,
             :state_id,
             :state_name,
             :latitude,
             :longitude
           ]}
  @primary_key false
  schema "locations" do
    field :zip_code, :string
    field :city_name, :string
    field :state_id, :string
    field :state_name, :string
    field :latitude, :float
    field :longitude, :float
  end

  def all(), do: Repo.all(__MODULE__)

  def get_buyers_locations() do
    from(b in Buyer, select: b.buyer_locations_of_interest)
    |> Repo.all()
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.map(fn location ->
      case Regex.run(~r/^\d{5}/, location) do
        [zip_code] -> zip_code
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.map(&Repo.get_by(Atlas.Location, zip_code: &1))
  end

  def all_states(),
    do: from(l in __MODULE__, select: %{state_id: l.state_id}) |> Repo.all() |> Enum.uniq()
end

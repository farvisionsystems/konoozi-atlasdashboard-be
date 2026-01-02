defmodule Atlas.Devices.Model do
  use Ecto.Schema
  import Ecto.Changeset

  schema "models" do
    field :deleted_at, :utc_datetime
    field :description, :string
    field :frame, :map
    field :image, :string
    field :name, :string
    field :slug, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [:slug, :name, :description, :frame, :image, :deleted_at])
    |> validate_required([:slug, :name, :description, :image, :deleted_at])
  end
end

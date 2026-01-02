defmodule Atlas.Images.Image do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset

  schema "images" do
    field :image, Atlas.ImageUploader.Type

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [:image])
    |> cast_attachments(attrs, [:image])
    |> validate_required([:image])
  end
end

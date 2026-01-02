defmodule Atlas.Cmd.Command do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :command, :device_id, :model_uid, :status, :inserted_at, :updated_at]}
  schema "commands_queue" do
    field :command, :string
    field :device_id, :id
    field :model_uid, :string
    field :status, :integer, default: 0
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(command, attrs) do
    command
    |> cast(attrs, [:device_id, :status, :command, :model_uid])
    |> validate_required([:device_id, :status, :command])
  end
end

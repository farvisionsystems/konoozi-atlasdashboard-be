defmodule Atlas.Devices.SensorDatum do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sensors_data" do
    field :deleted_at, :utc_datetime
    field :epoch, :integer
    field :error, :integer
    field :is_alarm, :integer
    field :value, :decimal
    belongs_to :sensor, Atlas.Devices.Sensor

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sensor_datum, attrs) do
    sensor_datum
    |> cast(attrs, [:value, :error, :sensor_id, :epoch, :is_alarm, :deleted_at])
    |> validate_required([:value, :sensor_id])
  end
end

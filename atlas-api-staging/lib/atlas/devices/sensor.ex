defmodule Atlas.Devices.Sensor do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sensors" do
    field :channel, :string
    field :deleted_at, :utc_datetime
    field :last_checkin_epoch, :integer
    field :name, :string
    field :retention_days, :integer
    field :sensor_type_uid, :integer
    field :status, :string, default: "active"
    field :input_selected, :boolean, default: false
    belongs_to :device, Atlas.Devices.Device
    has_many :sensor_data, Atlas.Devices.SensorDatum
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sensor, attrs) do
    sensor
    |> cast(attrs, [
      :name,
      :channel,
      :device_id,
      :sensor_type_uid,
      :retention_days,
      :last_checkin_epoch,
      :status,
      :deleted_at,
      :input_selected
    ])
    |> validate_required([:channel, :device_id])
  end

end

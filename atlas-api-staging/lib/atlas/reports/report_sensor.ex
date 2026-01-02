defmodule Atlas.Reports.ReportSensor do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "reports_sensors" do
    field :sensor_uid, :integer
    field :display_order, :integer

    belongs_to :report, Atlas.Reports.Report, foreign_key: :report_uid

    timestamps()
  end

  @doc false
  def changeset(report_sensor, attrs) do
    report_sensor
    |> cast(attrs, [:sensor_uid, :report_uid, :display_order])
    |> validate_required([:sensor_uid, :report_uid, :display_order])
    |> foreign_key_constraint(:report_uid)
  end
end

defmodule Atlas.Reports.ReportData do
  use Ecto.Schema
  import Ecto.Changeset

  schema "report_data" do
    belongs_to :report, Atlas.Reports.Report, type: :binary_id
    field :data, :map
    field :sample_interval, :string
    field :agg_function, :string
    field :generated_at, :utc_datetime

    timestamps()
  end

  def changeset(report_data, attrs) do
    report_data
    |> cast(attrs, [:report_id, :data, :sample_interval, :agg_function, :generated_at])
    |> validate_required([:report_id, :data, :sample_interval, :agg_function, :generated_at])
    |> foreign_key_constraint(:report_id)
  end
end

defmodule Atlas.Reports.ReportDistribution do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "reports_distribution" do
    field :contact_type, :string
    field :contact_value, :string

    belongs_to :report, Atlas.Reports.Report

    timestamps()
  end

  @doc false
  def changeset(report_distribution, attrs) do
    report_distribution
    |> cast(attrs, [:contact_type, :contact_value, :report_id])
    |> validate_required([:contact_type, :contact_value, :report_id])
    |> foreign_key_constraint(:report_id)
  end
end

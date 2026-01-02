defmodule Atlas.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [
    :id,
    :slug,
    :display_name,
    :active_status,
    :sample_interval,
    :run_interval,
    :run_now_duration,
    :agg_function,
    :distribution,
    :is_delete,
    :last_run_epoch,
    :organization_id,
    :created_by_id,
    :inserted_at,
    :updated_at,
  ]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :integer
  schema "reports" do
    field :slug, :string
    field :display_name, :string
    field :active_status, :boolean, default: false
    field :sample_interval, Ecto.Enum, values: [:hour_1, :hour_2, :hour_4, :hour_6, :hour_12, :hour_24]
    field :run_interval, Ecto.Enum, values: [:daily, :weekly, :monthly]
    field :run_now_duration, Ecto.Enum, values: [:day, :week, :month, :custom]
    field :agg_function, Ecto.Enum, values: [:first, :min, :ave, :max, :min_ave_max]
    field :distribution, Ecto.Enum, values: [:all_users, :specific_users, :manual_email_only, :no_distribution]
    field :is_delete, :boolean, default: false
    field :last_run_epoch, :integer

    belongs_to :organization, Atlas.Organizations.Organization, type: :integer
    belongs_to :created_by, Atlas.Accounts.User, foreign_key: :created_by_id, type: :integer
    has_many :reports_distribution, Atlas.Reports.ReportDistribution
    has_many :reports_sensors, Atlas.Reports.ReportSensor, foreign_key: :report_uid

    timestamps()
  end

  @doc false
  def changeset(report, attrs) do
    report
    |> cast(attrs, [:slug, :display_name, :active_status, :sample_interval, :run_interval,
                    :run_now_duration, :agg_function, :distribution, :organization_id,
                    :is_delete, :last_run_epoch, :created_by_id])
    |> validate_required([:slug, :display_name, :organization_id, :created_by_id])
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:organization_id)
    |> foreign_key_constraint(:created_by_id)
  end
end

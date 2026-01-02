defmodule Atlas.Repo.Migrations.AddReportHistory do
  use Ecto.Migration

  def change do
    create table(:report_data) do
      add :report_id, references(:reports, on_delete: :delete_all, type: :uuid), null: false
      add :data, :map
      add :sample_interval, :string  # or :integer depending on your needs
      add :agg_function, :string
      add :generated_at, :utc_datetime

      timestamps()
    end

    create index(:report_data, [:report_id])

  end
end

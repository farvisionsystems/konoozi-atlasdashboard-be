defmodule Atlas.Repo.Migrations.CreateReportsSensors do
  use Ecto.Migration

  def change do
    create table(:reports_sensors, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :report_uid, references(:reports, column: :id, type: :uuid, on_delete: :delete_all), null: false
      add :sensor_uid, :string, null: false
      add :display_order, :integer, null: false

      timestamps()
    end

    # Add indexes for better query performance
    create index(:reports_sensors, [:report_uid])
    create index(:reports_sensors, [:sensor_uid])
  end
end

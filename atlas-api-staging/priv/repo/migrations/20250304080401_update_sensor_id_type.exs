defmodule Atlas.Repo.Migrations.UpdateSensorIdType do
  use Ecto.Migration

  def change do
    # First remove the existing index
    drop index(:reports_sensors, [:sensor_uid])

    # Modify the column
    alter table(:reports_sensors) do
      remove :sensor_uid
      add :sensor_uid, references(:sensors, column: :id, type: :bigint, on_delete: :delete_all), null: false
    end

    # Add the index back (automatically created for foreign keys)
  end
end

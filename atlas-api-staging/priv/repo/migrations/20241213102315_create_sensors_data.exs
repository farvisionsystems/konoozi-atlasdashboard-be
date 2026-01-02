defmodule Atlas.Repo.Migrations.CreateSensorsData do
  use Ecto.Migration

  def change do
    create table(:sensors_data) do
      add :value, :decimal
      add :error, :integer
      add :epoch, :integer
      add :is_alarm, :integer
      add :deleted_at, :utc_datetime
      add :sensor_uid, references(:sensors, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:sensors_data, [:sensor_uid])
  end
end

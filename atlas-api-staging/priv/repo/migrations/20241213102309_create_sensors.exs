defmodule Atlas.Repo.Migrations.CreateSensors do
  use Ecto.Migration

  def change do
    create table(:sensors) do
      add :name, :string
      add :channel, :string
      add :sensor_type_uid, :integer
      add :retention_days, :integer
      add :last_checkin_epoch, :integer
      add :status, :string
      add :deleted_at, :utc_datetime
      add :device_id, references(:devices, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:sensors, [:device_id])
  end
end

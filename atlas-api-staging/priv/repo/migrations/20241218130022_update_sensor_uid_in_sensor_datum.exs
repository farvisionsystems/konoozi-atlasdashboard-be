defmodule Atlas.Repo.Migrations.UpdateSensorUidInSensorDatum do
  use Ecto.Migration

  def change do
    drop index(:sensors_data, [:sensor_uid])
    rename table("sensors_data"), :sensor_uid, to: :sensor_id
    create index(:sensors_data, [:sensor_id])
  end
end

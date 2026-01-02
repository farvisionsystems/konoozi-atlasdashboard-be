defmodule Atlas.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :name, :string
      add :mac_address, :string
      add :model, :string
      add :gateway_uid, :integer
      add :latitude, :decimal
      add :longitude, :decimal
      add :status, :string, default: "online"
      add :deleted_at, :utc_datetime
      add :organization_id, references(:organizations, on_delete: :nothing), null: true
      add :model_id, references(:models, on_delete: :nothing), null: true

      timestamps(type: :utc_datetime)
    end

    create index(:devices, [:organization_id])
    create index(:devices, [:model_id])
  end
end

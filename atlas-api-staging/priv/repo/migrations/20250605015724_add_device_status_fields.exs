defmodule Atlas.Repo.Migrations.AddDeviceStatusFields do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :tb, :string, size: 3, null: true
      add :sl, :string, size: 3, null: true
      add :pb, :string, size: 3, null: true
      add :tr, :string, size: 3, null: true
      add :rl, :string, size: 3, null: true
      add :ph, :string, size: 3, null: true
      add :alarm, :integer, null: true
      add :wn, :string, size: 24, null: true
      add :firmware_version, :string, size: 9, null: true
    end

    create index(:devices, [:firmware_version])

  end
end

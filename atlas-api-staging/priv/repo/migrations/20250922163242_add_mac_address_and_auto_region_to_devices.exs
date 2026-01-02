defmodule Atlas.Repo.Migrations.AddMacAddressAndAutoRegionToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :mac_address, :string
      add :auto_region, :string
    end
  end
end

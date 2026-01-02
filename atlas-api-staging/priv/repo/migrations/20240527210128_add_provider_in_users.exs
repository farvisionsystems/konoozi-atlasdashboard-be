defmodule Atlas.Repo.Migrations.AddProviderInUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :provider, :string, default: "password"
    end
  end

  def down do
    alter table(:users) do
      remove :provider
    end
  end
end

defmodule Atlas.Repo.Migrations.AddTimezoneColumn do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :timezone, :string, default: "UTC"
    end
  end

  # In case we need to roll back
  def down do
    alter table(:devices) do
      remove :timezone
    end
  end
end

defmodule Atlas.Repo.Migrations.AddFirstAndLastNamesInUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :first_name, :string
      add :last_name, :string
      remove :full_name
    end
  end

  def down do
    alter table(:users) do
      remove :first_name
      remove :last_name
      add :full_name, :string
    end
  end
end

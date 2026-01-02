defmodule Atlas.Repo.Migrations.AddNameFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :first_name, :string
      add :last_name, :string
    end

    # Create an index for searching by name
    create index(:users, [:first_name, :last_name])
  end

  # In case we need to roll back
  def down do
    alter table(:users) do
      remove :first_name
      remove :last_name
    end

    drop index(:users, [:first_name, :last_name])
  end
end

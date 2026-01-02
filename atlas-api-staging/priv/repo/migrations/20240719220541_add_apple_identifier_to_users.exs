defmodule Atlas.Repo.Migrations.AddAppleIdentifierToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :apple_identifier, :string
    end

    create unique_index(:users, [:apple_identifier])
  end
end

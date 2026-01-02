defmodule Atlas.Repo.Migrations.AddFavouriteToBuyers do
  use Ecto.Migration

  def up do
    alter table(:buyers) do
      add :is_favourite, :boolean, default: false
    end
  end

  def down do
    alter table(:buyers) do
      remove :is_favourite
    end
  end
end

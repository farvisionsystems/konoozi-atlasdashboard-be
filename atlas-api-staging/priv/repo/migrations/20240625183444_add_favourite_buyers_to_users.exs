defmodule Atlas.Repo.Migrations.AddFavouriteBuyersToUsers do
  use Ecto.Migration

  def up do
    alter table(:buyers) do
      remove :is_favourite
    end

    alter table(:users) do
      add :favourite_buyers, {:array, :integer}, default: []
    end
  end

  def down do
    alter table(:buyers) do
      add :is_favourite, :boolean, default: false
    end

    alter table(:users) do
      remove :favourite_buyers
    end
  end
end

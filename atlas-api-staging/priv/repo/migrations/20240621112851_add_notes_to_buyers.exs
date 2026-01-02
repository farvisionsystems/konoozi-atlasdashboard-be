defmodule Atlas.Repo.Migrations.AddNotesToBuyers do
  use Ecto.Migration

  def up do
    alter table(:buyers) do
      add :notes, :string
    end
  end

  def down do
    alter table(:buyers) do
      remove :notes
    end
  end
end

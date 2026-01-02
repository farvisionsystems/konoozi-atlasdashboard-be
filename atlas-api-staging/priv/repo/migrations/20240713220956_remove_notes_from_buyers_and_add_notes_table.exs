defmodule Atlas.Repo.Migrations.RemoveNotesFromBuyersAndAddNotesTable do
  use Ecto.Migration

  def up do
    alter table(:buyers) do
      remove :notes
    end

    create table(:notes) do
      add :content, :string
      add :buyer_id, references(:buyers, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end
  end

  def down do
    alter table(:buyers) do
      add :notes, :string
    end

    drop(table(:notes))
  end
end

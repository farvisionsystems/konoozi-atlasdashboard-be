defmodule Atlas.Repo.Migrations.AddIsArchievedToThreadUsers do
  use Ecto.Migration

  def up do
    alter table(:threads) do
      remove :is_archieved
      remove :archieved_at
    end

    alter table(:threads_users) do
      add :is_archived, :boolean, default: false
      add :archived_at, :naive_datetime
    end
  end

  def down do
    alter table(:threads) do
      add :is_archieved, :boolean, default: false
      add :archieved_at, :naive_datetime
    end

    alter table(:threads_users) do
      remove :is_archived
      remove :archived_at
    end
  end
end

defmodule Atlas.Repo.Migrations.AddIsDeletedInMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :is_deleted, :boolean, default: false
    end
  end
end

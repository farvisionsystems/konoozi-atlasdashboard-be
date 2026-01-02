defmodule Atlas.Repo.Migrations.AddCreatedByToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :created_by_id, references(:users, on_delete: :delete_all)
    end
  end
end

defmodule Atlas.Repo.Migrations.AddOrganizationsTable do
  use Ecto.Migration

  def up do
    create table(:organizations) do
      add :name, :string
      add :profile, :map, default: fragment("'{}'::jsonb")
      add :is_active, :boolean, null: false, default: true
      add :logo, :string
      # add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end
  end

  def down do
    drop(table(:organizations))
  end
end

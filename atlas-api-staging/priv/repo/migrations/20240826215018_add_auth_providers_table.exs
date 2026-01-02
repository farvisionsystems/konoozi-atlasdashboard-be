defmodule Atlas.Repo.Migrations.AddAuthProvidersTable do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :provider
      modify :hashed_password, :string, null: true
    end

    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:auth_providers) do
      add :email, :citext
      add :provider, :string, null: false
      add :apple_identifier, :string
      add :is_approved, :boolean
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end
  end

  def down do
    alter table(:users) do
      add :provider, :string, default: "password"
      modify :hashed_password, :string, null: false
    end

    drop table(:auth_providers)
  end
end

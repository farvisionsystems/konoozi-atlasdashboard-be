defmodule Atlas.Repo.Migrations.CreateUserOrganizationsTable do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE organization_status AS ENUM ('active', 'inactive', 'deleted')"

    create table(:users_organizations, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
      add :status, :string
      add :org_status, :organization_status, null: false, default: "active"
      add(:role_id, references(:acl_roles, on_delete: :nothing))

      timestamps()
    end

    create unique_index(:users_organizations, [:user_id, :organization_id])
  end
end

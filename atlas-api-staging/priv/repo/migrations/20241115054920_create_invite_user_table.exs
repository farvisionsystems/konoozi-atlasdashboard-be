defmodule Atlas.Repo.Migrations.AddInviteUserTable do
  use Ecto.Migration

  def change do
    create table(:invite_tokens) do
      add :token, :string, null: false
      add :email, :string, null: false
      add :expires_at, :naive_datetime, null: false
      add :used, :boolean, default: false, null: false

      add(:organization_id, references(:organizations, on_delete: :nothing))
      add(:role_id, references(:acl_roles, on_delete: :nothing))
      timestamps()
    end

    create unique_index(:invite_tokens, [:token])
    create index(:invite_tokens, [:organization_id])
  end
end

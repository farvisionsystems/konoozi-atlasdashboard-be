defmodule Atlas.Repo.Migrations.AddActiveOrganizationInUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :organization_id, references(:organizations, on_delete: :delete_all), null: false
    end
  end
end

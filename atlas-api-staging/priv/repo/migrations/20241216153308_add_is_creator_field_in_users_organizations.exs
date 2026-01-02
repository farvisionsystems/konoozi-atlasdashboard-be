defmodule Atlas.Repo.Migrations.AddIsCreatorFieldInUsersOrganizations do
  use Ecto.Migration

  def change do
    alter table(:users_organizations) do
      add :is_creator, :boolean, default: false
    end
  end
end

defmodule Atlas.Repo.Migrations.UpdateUsersTableWithProfileInformations do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :full_name, :string
      add :phone_number_primary, :string
      add :phone_number_optional, :string
      add :avatar, :string
    end
  end

  def down do
    alter table(:users) do
      remove :full_name
      remove :phone_number_primary
      remove :phone_number_optional
      remove :avatar
    end
  end
end

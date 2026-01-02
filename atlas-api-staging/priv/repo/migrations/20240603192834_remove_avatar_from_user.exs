defmodule Atlas.Repo.Migrations.RemoveAvatarFromUser do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :avatar
    end
  end

  def down do
    alter table(:users) do
      add :avatar, :string
    end
  end
end

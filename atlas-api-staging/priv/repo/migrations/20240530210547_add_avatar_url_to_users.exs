defmodule Atlas.Repo.Migrations.AddAvatarUrlToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :image_url, :string
    end
  end

  def down do
    alter table(:users) do
      remove :image_url
    end
  end
end

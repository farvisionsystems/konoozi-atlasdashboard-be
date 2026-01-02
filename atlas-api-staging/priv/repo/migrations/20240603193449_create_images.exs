defmodule Atlas.Repo.Migrations.CreateImages do
  use Ecto.Migration

  def change do
    create table(:images) do
      add :image, :string

      timestamps(type: :utc_datetime)
    end
  end
end

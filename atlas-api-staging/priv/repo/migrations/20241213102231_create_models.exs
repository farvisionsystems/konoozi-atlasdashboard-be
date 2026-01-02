defmodule Atlas.Repo.Migrations.CreateModels do
  use Ecto.Migration

  def change do
    create table(:models) do
      add :slug, :string
      add :name, :string
      add :description, :string
      add :frame, :map
      add :image, :string
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end

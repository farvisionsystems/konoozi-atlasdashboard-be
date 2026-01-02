defmodule Atlas.Repo.Migrations.AddInputSelectedToSensors do
  use Ecto.Migration

  def change do
    alter table(:sensors) do
      add :input_selected, :boolean, default: false, null: false
    end
  end
end

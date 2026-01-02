defmodule Atlas.Repo.Migrations.CreateCommandsQueue do
  use Ecto.Migration

  def change do
    create table(:commands_queue) do
      add :device_mac, :string
      add :status, :integer
      add :command, :string
      add :model_uid, :string

      timestamps(type: :utc_datetime)
    end
  end
end

defmodule Atlas.Repo.Migrations.AddUserIdToDevices do
  use Ecto.Migration

    def change do
      alter table(:devices) do
        add :user_id, references(:users, on_delete: :nothing)
      end

      create index(:devices, [:user_id])
    end
end

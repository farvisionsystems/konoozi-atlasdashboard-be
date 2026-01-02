defmodule Atlas.Repo.Migrations.AddChatUsers do
  use Ecto.Migration

  def up do
    alter table(:threads) do
      remove(:user_1_id)
      remove(:user_2_id)
    end

    create table(:threads_users) do
      add :thread_id, references(:threads, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)
    end
  end

  def down do
    alter table(:threads) do
      add :user_1_id, references(:users, on_delete: :nothing), null: true
      add :user_2_id, references(:users, on_delete: :nothing), null: true
    end

    drop(table(:threads_users))
  end
end

defmodule Atlas.Repo.Migrations.AddThreadsAndMessagesTable do
  use Ecto.Migration

  def change do
    create table(:threads) do
      add :user_1_id, references(:users, on_delete: :nothing), null: true
      add :user_2_id, references(:users, on_delete: :nothing), null: true
      add :is_archieved, :boolean, default: false
      add :archieved_at, :naive_datetime
      add :buyer_id, references(:buyers, on_delete: :nothing), null: true

      timestamps(type: :utc_datetime)
    end

    create table(:messages) do
      add :content, :string
      add :sent_by, :integer
      add :received_by, :integer
      add :attachements, :string
      add :is_read, :boolean
      add :initiated_at, :utc_datetime
      add :thread_id, references(:threads, on_delete: :delete_all), null: false
      add :is_edited, :boolean
      add :edited_at, :utc_datetime
      add :parent_id, :integer

      timestamps(type: :utc_datetime)
    end
  end
end

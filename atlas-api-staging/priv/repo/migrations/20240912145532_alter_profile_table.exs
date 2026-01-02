defmodule Atlas.Repo.Migrations.AlterProfileTable do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      modify :agent_email, :string, null: true
      modify :first_name, :string, null: true
      modify :last_name, :string, null: true
      modify :phone_number_primary, :string, null: true
      modify :brokerage_name, :string, null: true
      modify :brokerage_lisence_no, :string, null: true
      modify :lisence_id_no, :string, null: true
    end
  end
end

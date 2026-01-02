defmodule Atlas.Repo.Migrations.UpdateUsersTableWithBrokerInformation do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :company_name
      remove :real_estate_lisence_no
      remove :broker_lisence_no
      remove :state
      remove :zip_codes
      remove :search_range
      add :brokerage_name, :string
      add :brokerage_lisence_no, :string
      add :broker_street_address, :string
      add :broker_city, :string
      add :brokerage_zip_code, :string
      add :brokerage_state, :string
      add :is_completed, :boolean, default: false
    end
  end

  def down do
    alter table(:users) do
      add :company_name, :string
      add :real_estate_lisence_no, :string
      add :broker_lisence_no, :string
      add :state, :string
      add :zip_codes, {:array, :integer}
      add :search_range, :string
      remove :brokerage_name
      remove :brokerage_lisence_no
      remove :broker_street_address
      remove :broker_city
      remove :brokerage_zip_code
      remove :brokerage_state
      remove :is_completed
    end
  end
end

defmodule Atlas.Repo.Migrations.AddCompanyFieldsToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :company_name, :string
      add :real_estate_lisence_no, :string
      add :broker_lisence_no, :string
      add :state, :string
      add :zip_codes, {:array, :integer}
      add :search_range, :string
    end
  end

  def down do
    alter table(:users) do
      remove :company_name
      remove :real_estate_lisence_no
      remove :broker_lisence_no
      remove :state
      remove :zip_codes
      remove :search_range
    end
  end
end

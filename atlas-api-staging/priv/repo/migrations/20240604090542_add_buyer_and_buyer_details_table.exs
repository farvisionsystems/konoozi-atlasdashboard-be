defmodule Atlas.Repo.Migrations.AddBuyerAndBuyerDetailsTable do
  use Ecto.Migration

  @purchase "buyer_purchase_type"
  @property "buyer_property_type"
  @financial_status "buyer_financial_status"
  @timeline "buyer_rental_timeline"

  def up do
    create table(:buyers) do
      add :first_name, :string
      add :last_name, :string
      add :image_url, :string
      add :buyers_alias, :string
      add :email, :string
      add :primary_phone_number, :string
      add :optional_phone_number, :string
      add :buyer_locations, {:array, :string}
      add :additional_desires, {:array, :string}
      add :agreement_expiry_date, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    execute(
      "CREATE TYPE #{@purchase} AS ENUM ('buy','rent')",
      "DROP TYPE #{@purchase}"
    )

    execute(
      "CREATE TYPE #{@timeline} AS ENUM ('asap','3_months', '6_months', '1_year_plus')",
      "DROP TYPE #{@timeline}"
    )

    execute(
      "CREATE TYPE #{@financial_status} AS ENUM ('pre_qualified','pre_approved', 'all_cash', 'undeterminded')",
      "DROP TYPE #{@financial_status}"
    )

    execute(
      "CREATE TYPE #{@property} AS ENUM ('single_family_house','townhouse', 'condo', 'apartment', 'multi_family_house', 'mobile', 'land', 'fixer')",
      "DROP TYPE #{@property}"
    )

    create table(:buyer_needs) do
      add(:purchase_type, :"#{@purchase}")
      add(:property_type, :"#{@property}")
      add(:financial_status, :"#{@financial_status}")
      add(:timeline, :"#{@timeline}")
      add(:budget_upto, :string)
      add(:min_bedrooms, :string)
      add(:min_bathrooms, :string)
      add(:min_area, :string)
      add :buyer_id, references(:buyers, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end
  end

  def down do
    drop(table(:buyer_needs))
    execute("DROP TYPE #{@purchase}")
    execute("DROP TYPE #{@timeline}")
    execute("DROP TYPE #{@financial_status}")
    execute("DROP TYPE #{@property}")
    drop(table(:buyers))
  end
end

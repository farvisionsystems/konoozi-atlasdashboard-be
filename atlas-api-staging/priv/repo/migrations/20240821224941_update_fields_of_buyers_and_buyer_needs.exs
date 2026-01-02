defmodule Atlas.Repo.Migrations.UpdateFieldsOfBuyersAndBuyerNeeds do
  use Ecto.Migration

  @property "buyer_property_type"
  @financial_status "buyer_financial_status"
  @purchase "buyer_purchase_type"

  def change do
    rename table("buyers"), :buyer_locations, to: :buyer_locations_of_interest
    rename table("buyers"), :additional_desires, to: :additional_requests
    rename table("buyers"), :agreement_expiry_date, to: :buyer_expiration_date

    alter table(:buyers) do
      remove :buyers_alias
      remove :optional_phone_number

      modify :email, :string, null: true
      modify :primary_phone_number, :string, null: true
      modify :additional_requests, {:array, :string}, null: true
    end

    execute "DROP TYPE IF EXISTS #{@property} CASCADE;"

    execute(
      "CREATE TYPE #{@property} AS ENUM ('single_family_house','townhouse', 'condo', 'apartment', 'multi_family_house', 'mobile', 'land')",
      "DROP TYPE #{@property}"
    )

    execute "DROP TYPE IF EXISTS #{@financial_status} CASCADE;"

    execute(
      "CREATE TYPE #{@financial_status} AS ENUM ('pre_qualified','pre_approved', 'all_cash', 'n_a')",
      "DROP TYPE #{@financial_status}"
    )

    execute("DROP TYPE IF EXISTS #{@purchase} CASCADE;")

    execute(
      "CREATE TYPE #{@purchase} AS ENUM ('purchase','lease')",
      "DROP TYPE #{@purchase}"
    )

    alter table(:buyer_needs) do
      remove :property_type
      add(:property_type, :"#{@property}")

      add(:financial_status, :"#{@financial_status}")

      add(:purchase_type, :"#{@purchase}")
    end

    execute("""
    ALTER TABLE buyers
    ALTER COLUMN first_name SET NOT NULL,
    ALTER COLUMN last_name SET NOT NULL,
    ALTER COLUMN buyer_locations_of_interest SET NOT NULL,
    ALTER COLUMN buyer_expiration_date SET NOT NULL
    """)

    execute """
    UPDATE buyer_needs
    SET purchase_type = 'purchase'
    WHERE purchase_type IS NULL;
    """

    execute """
    UPDATE buyer_needs
    SET property_type = 'single_family_house'
    WHERE property_type IS NULL;
    """

    execute """
    UPDATE buyer_needs
    SET financial_status = 'n_a'
    WHERE financial_status IS NULL;
    """

    execute("""
    ALTER TABLE buyer_needs
    ALTER COLUMN purchase_type SET NOT NULL,
    ALTER COLUMN property_type SET NOT NULL,
    ALTER COLUMN financial_status SET NOT NULL,
    ALTER COLUMN budget_upto SET NOT NULL,
    ALTER COLUMN min_bedrooms SET NOT NULL,
    ALTER COLUMN min_bathrooms SET NOT NULL,
    ALTER COLUMN min_area SET NOT NULL
    """)
  end
end

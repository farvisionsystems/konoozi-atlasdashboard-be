defmodule Atlas.Repo.Migrations.RenameEnums do
  use Ecto.Migration

  @timeline "buyer_rental_timeline"
  @new_timeline "new_buyer_rental_timeline"
  @property "buyer_property_type"
  @new_property "new_buyer_property_type"

  def change do
    # Step 1: Create new enum types with the updated values
    execute(
      "CREATE TYPE #{@new_timeline} AS ENUM ('asap','three_months', 'six_months', 'open')",
      "DROP TYPE #{@new_timeline}"
    )

    execute(
      "CREATE TYPE #{@new_property} AS ENUM ('single_family_house','townhouse', 'condo', 'apartment', 'multi_family_house', 'mobile', 'fixer')",
      "DROP TYPE #{@new_property}"
    )

    # Step 2: Alter the existing columns to use the new enum types
    alter table(:buyer_needs) do
      add :new_timeline, :"#{@new_timeline}"
      add :new_property_type, :"#{@new_property}"
    end

    # Step 3: Update existing records to use the new enum values
    execute("""
      UPDATE buyer_needs
      SET new_timeline = CASE
        WHEN timeline = 'one_year_plus' THEN 'open'
        ELSE timeline::text::#{@new_timeline}
      END
    """)

    execute("""
      UPDATE buyer_needs
      SET new_property_type = CASE
        WHEN property_type = 'land' THEN 'townhouse'
        ELSE property_type::text::#{@new_property}
      END
    """)

    # Step 4: Drop the old columns
    alter table(:buyer_needs) do
      remove :timeline
      remove :property_type
    end

    # Step 5: Rename the new columns to the original names
    execute("ALTER TABLE buyer_needs RENAME COLUMN new_timeline TO timeline")
    execute("ALTER TABLE buyer_needs RENAME COLUMN new_property_type TO property_type")

    # Step 6: Drop the old enum types
    execute("DROP TYPE #{@timeline}")
    execute("DROP TYPE #{@property}")
  end
end

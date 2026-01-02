defmodule Atlas.Repo.Migrations.AlterBuyerNeedsTable do
  use Ecto.Migration

  def up do
    # Convert min_bedrooms
    execute("""
    ALTER TABLE buyer_needs
    ALTER COLUMN min_bedrooms DROP NOT NULL,
    ALTER COLUMN min_bedrooms TYPE double precision USING
    CASE
      WHEN trim(min_bedrooms) = '' THEN NULL
      ELSE min_bedrooms::double precision
    END
    """)

    # Convert min_bathrooms
    execute("""
    ALTER TABLE buyer_needs
    ALTER COLUMN min_bathrooms DROP NOT NULL,
    ALTER COLUMN min_bathrooms TYPE double precision USING
    CASE
      WHEN trim(min_bathrooms) = '' THEN NULL
      ELSE min_bathrooms::double precision
    END
    """)

    # Convert min_area
    execute("""
    ALTER TABLE buyer_needs
    ALTER COLUMN min_area DROP NOT NULL,
    ALTER COLUMN min_area TYPE double precision USING
    CASE
      WHEN trim(min_area) = '' THEN NULL
      ELSE min_area::double precision
    END
    """)

    # Update NULL values to default values (e.g., 0.0) if needed
    execute("UPDATE buyer_needs SET min_bedrooms = 0.0 WHERE min_bedrooms IS NULL")
    execute("UPDATE buyer_needs SET min_bathrooms = 0.0 WHERE min_bathrooms IS NULL")
    execute("UPDATE buyer_needs SET min_area = 0.0 WHERE min_area IS NULL")

    # Enforce NOT NULL constraints
    execute("ALTER TABLE buyer_needs ALTER COLUMN min_bedrooms SET NOT NULL")
    execute("ALTER TABLE buyer_needs ALTER COLUMN min_bathrooms SET NOT NULL")
    execute("ALTER TABLE buyer_needs ALTER COLUMN min_area SET NOT NULL")
  end

  def down do
    # Reverse the migration
    execute("""
    ALTER TABLE buyer_needs
    ALTER COLUMN min_bedrooms TYPE text USING min_bedrooms::text,
    ALTER COLUMN min_bedrooms SET NOT NULL
    """)

    execute("""
    ALTER TABLE buyer_needs
    ALTER COLUMN min_bathrooms TYPE text USING min_bathrooms::text,
    ALTER COLUMN min_bathrooms SET NOT NULL
    """)

    execute("""
    ALTER TABLE buyer_needs
    ALTER COLUMN min_area TYPE text USING min_area::text,
    ALTER COLUMN min_area SET NOT NULL
    """)
  end
end

defmodule Atlas.Repo.Migrations.PopulateSkuInBuyers do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE buyers
    SET sku = (
      'BB-' ||
      UPPER(SUBSTRING(buyers.last_name, 1, 6)) || '-' ||
      LPAD(CAST(buyers.user_id + 1000 AS TEXT), 4, '0') || '#' ||
      LPAD(CAST(buyers.id + 1000 AS TEXT), 4, '0')
    )
    """)
  end

  def down do
    execute("""
    UPDATE buyers
    SET sku = NULL
    """)
  end
end

defmodule Atlas.Repo.Migrations.ReplaceMobileWithLandInPropertyType do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE buyer_needs
    SET property_type = 'land'
    WHERE property_type = 'mobile';
    """)
  end

  def down do
    execute("""
    UPDATE buyer_needs
    SET property_type = 'mobile'
    WHERE property_type = 'land';
    """)
  end
end

defmodule Atlas.Repo.Migrations.UpdateAclResource do
  use Ecto.Migration

  def change do
    # Step 1: Delete acl_rules with resource_id of "organizations"
    execute("""
    DELETE FROM acl_rules
    WHERE resource_id IN (
      SELECT id FROM acl_resources WHERE resource = 'organizations'
    )
    """)

    # Step 2: Delete acl_resources with the resource "organizations"
    execute("""
    DELETE FROM acl_resources
    WHERE resource = 'organizations'
    """)
  end
end

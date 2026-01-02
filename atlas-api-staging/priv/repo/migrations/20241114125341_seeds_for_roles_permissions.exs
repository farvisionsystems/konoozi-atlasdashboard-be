defmodule Atlas.Repo.Migrations.SeedsForRolesPermissions do
  use Ecto.Migration

  def change do
    # -- Insert resources
    execute("
      INSERT INTO acl_resources
      (resource, parent, inserted_at, updated_at)
      VALUES
        ('organizations', NULL, '2024-04-01 15:35:48.000', '2024-04-01 15:35:48.000'),
        ('users', NULL, '2024-04-01 15:35:48.000', '2024-04-01 15:35:48.000'),
        ('locations', NULL, '2024-04-01 15:35:48.000', '2024-04-01 15:35:48.000'),
        ('devices', NULL, '2024-04-01 15:35:48.000', '2024-04-01 15:35:48.000')
    ")

    # -- Insert roles
    execute("
      INSERT INTO acl_roles
      (\"role\", is_member, parent, inserted_at, updated_at)
      VALUES
        ('super_admin', true, NULL, '2024-04-02 15:35:48.000', '2024-04-02 15:35:48.000'),
        ('admin', true, NULL, '2024-04-03 15:35:48.000', '2024-04-03 15:35:48.000'),
        ('user', true, NULL, '2024-04-04 15:35:48.000', '2024-04-04 15:35:48.000')
    ")

    # -- Define rules for super_admin (edit)
    execute("
      INSERT INTO acl_rules
      (role_id, resource_id, action, permission, inserted_at, updated_at)
      SELECT 
        (SELECT id FROM acl_roles WHERE role = 'super_admin') AS role_id, 
        id AS resource_id,
        'edit' AS action,
        4 AS permission,
        '2024-04-05 15:35:48.000' AS inserted_at,
        '2024-04-05 15:35:48.000' AS updated_at
      FROM acl_resources
    ")

    # -- Define rules for admin (write)
    execute("
      INSERT INTO acl_rules
      (role_id, resource_id, action, permission, inserted_at, updated_at)
      SELECT 
        (SELECT id FROM acl_roles WHERE role = 'admin') AS role_id, 
        id AS resource_id,
        'write' AS action,
        2 AS permission,
        '2024-04-05 15:35:48.000' AS inserted_at,
        '2024-04-05 15:35:48.000' AS updated_at
      FROM acl_resources
    ")

    # -- Define rules for user (read)
    execute("
      INSERT INTO acl_rules
      (role_id, resource_id, action, permission, inserted_at, updated_at)
      SELECT 
        (SELECT id FROM acl_roles WHERE role = 'user') AS role_id, 
        id AS resource_id,
        'read' AS action,
        1 AS permission,
        '2024-04-05 15:35:48.000' AS inserted_at,
        '2024-04-05 15:35:48.000' AS updated_at
      FROM acl_resources
    ")
  end
end

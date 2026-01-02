defmodule Atlas.Roles do
  import Ecto.Query, warn: false

  alias Atlas.Repo
  alias Ecto.Multi
  alias Acl.ACL.{Role, Rule, Resource}
  alias Atlas.Organizations.UserOrganization

  def get_role_by_organization_name(organization_id, role_name) do
    query =
      if is_nil(organization_id) do
        from(r in Role, where: r.role == ^role_name and is_nil(r.organization_id))
      else
        from(r in Role, where: r.role == ^role_name and r.organization_id == ^organization_id)
      end

    Repo.one(query)
  end

  def get_role_by_organization_id(organization_id, role_id) do
    from(r in Role, where: r.id == ^role_id and r.organization_id == ^organization_id)
    |> Repo.one()
  end

  def get_role_rules_by_user_organization(user_id, organization_id) do
    from(r in Role,
      join: uo in UserOrganization,
      on: uo.role_id == r.id,
      where: uo.user_id == ^user_id and uo.organization_id == ^organization_id,
      preload: [
        rules: [:resource]
      ]
    )
    |> Repo.one()
  end

  def get_rules_by_role_id(role_id) do
    from(r in Role,
      where: r.id == ^role_id,
      preload: [
        rules: [
          :role,
          :resource
        ]
      ]
    )
    |> Repo.one()
    |> case do
      nil -> {nil, []}
      role -> {role.role, role.rules}
    end
  end

  def get_default_roles do
    Role
    |> where([r], is_nil(r.organization_id))
    |> Repo.all()
    |> Repo.preload(:rules)
  end

  def get_organization_roles(organization_id) do
    Role
    |> where([r], r.organization_id == ^organization_id)
    |> Repo.all()
    |> Repo.preload(:rules)
  end

  def get_organization_roles_with_user_counts(organization_id) do
    from(r in Role,
      where: r.organization_id == ^organization_id,
      left_join: uo in Atlas.Organizations.UserOrganization,
      on: uo.role_id == r.id,
      left_join: it in Atlas.Accounts.InviteToken,
      # Adjust condition as needed
      on: it.role_id == r.id and it.organization_id == ^organization_id,
      group_by: r.id,
      select: %{
        role: r,
        # Count of users in UserOrganization
        users_count: fragment("COALESCE(?, 0)", count(uo.user_id)),
        # Count of invited users in InvitedToken
        invited_count: fragment("COALESCE(?, 0)", count(it.id))
      }
    )
    |> Repo.all()
    |> Enum.map(fn %{role: role, users_count: users_count, invited_count: invited_count} ->
      role
      |> Repo.preload(:rules)
      # Add users_count and invited_count
      |> Map.put(:users_count, users_count + invited_count)
    end)
  end

  def list_resources do
    Repo.all(Resource)
  end

  def get_role_resource_rules(organization_id) do
    roles = get_organization_roles_with_user_counts(organization_id)
    resources = list_resources()

    %{roles: roles, resources: resources}
  end

  def get_roles(organization_id) do
    from(r in Role,
      where: r.organization_id == ^organization_id
    )
    |> Repo.all()
  end

  def create_role_with_rules(params, organization_id) do
    Multi.new()
    |> Multi.insert(
      :role,
      Role.changeset(%Role{}, %{
        is_member: true,
        role: params["role"],
        organization_id: organization_id
      })
      |> validate_role_name()
    )
    |> Multi.run(:rules, fn repo, %{role: role} ->
      rules = params["rules"]

      # Map rules into changesets
      rule_changesets =
        rules
        |> Enum.map(fn rule ->
          permission = get_rule_by_action(rule["action"])

          Rule.u_changeset(%Rule{}, %{
            role_id: role.id,
            action: rule["action"],
            permission: permission,
            resource_id: rule["resource_id"],
            organization_id: organization_id
          })
        end)

      results = Enum.map(rule_changesets, &Repo.insert(&1))

      Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)
      |> case do
        true ->
          {:ok, role}

        _ ->
          {:error, "Failed to insert rules"}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, role} -> {:ok, role}
      {:error, _, reason, _} -> {:error, reason}
    end
  end

  def create_default_roles_and_rules(organization_id) do
    get_default_roles()
    |> Enum.map(fn role ->
      insert_role_with_rules(role, organization_id)
    end)
  end

  def insert_role_with_rules(role, organization_id) do
    role_params =
      role
      |> Map.from_struct()
      |> Map.drop([:__meta__, :rules])
      |> Map.put(:organization_id, organization_id)

    Role.changeset(%Role{}, role_params)
    |> Repo.insert()
    |> case do
      {:ok, new_role} ->
        Enum.map(role.rules, fn rule ->
          params =
            rule
            |> Map.from_struct()
            |> Map.drop([:__meta__, :rules])
            |> Map.put(:role_id, new_role.id)

          Acl.ACL.Rule.u_changeset(%Acl.ACL.Rule{}, params)
          |> Repo.insert()
        end)

        new_role

      _ ->
        {:error, role}
    end
  end

  def update_rules(%{"_json" => rules}) do
    multi =
      Enum.reduce(rules, Multi.new(), fn %{
                                           "resource_id" => resource_id,
                                           "role_id" => role_id,
                                           "action" => action
                                         },
                                         multi ->
        permission = get_rule_by_action(action)

        Multi.run(multi, "#{resource_id}_#{role_id}_#{action}", fn _repo, _changes ->
          case Repo.get_by(Rule, resource_id: resource_id, role_id: role_id) do
            nil ->
              %Rule{}
              |> Rule.u_changeset(%{
                resource_id: resource_id,
                role_id: role_id,
                action: action,
                permission: permission
              })
              |> Repo.insert()

            rule ->
              rule
              |> Rule.u_changeset(%{action: action, permission: permission})
              |> Repo.update()
          end
        end)
      end)

    Repo.transaction(multi)
  end

  def update_rules(resources, role_id) do
    Enum.map(resources, fn {resource_id, %{"permission" => permission}} ->
      get_and_update_rule(resource_id, role_id, permission)
    end)
  end

  def get_and_update_rule(resource_id, role_id, action) do
    permission = get_rule_by_action(action)

    Repo.get_by(Acl.ACL.Rule, resource_id: resource_id, role_id: role_id)
    |> case do
      nil ->
        Acl.ACL.Rule.u_changeset(%Acl.ACL.Rule{}, %{
          resource_id: resource_id,
          role_id: role_id,
          action: action,
          permission: permission
        })
        |> Repo.insert()

      rule ->
        Acl.ACL.Rule.u_changeset(rule, %{action: action, permission: permission})
        |> Repo.update()
    end
  end

  def delete_role(role_id) do
    Multi.new()
    |> Multi.run(:check_user_organizations, fn _repo, _changes ->
      case Repo.exists?(
             from(uo in Atlas.Organizations.UserOrganization, where: uo.role_id == ^role_id)
           ) do
        true -> {:error, "Cannot delete role because users are associated with it."}
        false -> {:ok, :no_users}
      end
    end)
    |> Multi.delete_all(:delete_rules, from(r in Rule, where: r.role_id == ^role_id))
    |> Multi.delete_all(:delete_role, from(r in Role, where: r.id == ^role_id))
    |> Repo.transaction()
    |> case do
      {:ok, _} -> {:ok, "Role and associated rules deleted successfully."}
      {:error, :check_user_organizations, reason, _} -> {:error, reason}
      {:error, step, reason, _changes} -> {:error, reason}
    end
  end

  defp get_rule_by_action(action) do
    case action do
      "read" -> 1
      "write" -> 2
      "delete" -> 3
      "edit" -> 4
      _ -> 0
    end
  end

  defp validate_role_name(changeset) do
    changeset
    |> Ecto.Changeset.validate_format(:role, ~r/^[a-zA-Z0-9 ]*$/,
      message: "Role name can only contain letters, numbers, and spaces"
    )
  end
end

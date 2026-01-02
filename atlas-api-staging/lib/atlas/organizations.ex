defmodule Atlas.Organizations do
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Atlas.{Accounts, Repo, Organizations}
  alias Organizations.{Organization, UserOrganization}

  def get_organizations(organization_ids) do
    from(o in Organization,
      where: o.id in ^organization_ids,
      order_by: [desc: o.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single organization by ID.

  Raises `Ecto.NoResultsError` if the Organization does not exist.

  ## Examples

      iex> get_organization!(123)
      %Organization{}

      iex> get_organization!(456)
      ** (Ecto.NoResultsError)

  """
  def get_organization!(id), do: Repo.get!(Organization, id)

  def create_organization_with_out_user(organization_name) do
    %Organization{}
    |> Organization.changeset(%{name: organization_name})
    |> Atlas.Repo.insert()
  end

  def create_organization(params, user_id) do
    Multi.new()
    |> Multi.insert(:organization, Organization.changeset(%Organization{}, params))
    |> Multi.run(:roles, fn _repo, %{organization: organization} ->
      {:ok, Atlas.Roles.create_default_roles_and_rules(organization.id)}
    end)
    |> Multi.run(:user_organization, fn _repo, %{organization: organization, roles: roles} ->
      role =
        Enum.find(roles, fn role -> role.role == "super_admin" end) ||
          Atlas.Roles.get_role_by_organization_id(organization.id, "super_admin")

      %UserOrganization{}
      |> UserOrganization.changeset(%{
        user_id: user_id,
        organization_id: organization.id,
        role_id: role.id,
        status: "Active",
        is_creator: true
      })
      |> Repo.insert()
    end)
    |> Multi.run(:update_user, fn _repo, %{organization: organization} ->
      if params["switch_organization?"] do
        Accounts.get_user(user_id)
        |> Accounts.User.organization_changeset(%{organization_id: organization.id})
        |> Repo.update()
      else
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{organization: organization}} ->
        {:ok, organization}

      {:error, _, changeset, _} = error ->
        {:error, changeset}
    end
  end

  def update_organization(id, params) do
    Repo.get(Organization, id)
    |> case do
      nil ->
        {:error, "not_found"}

      organization ->
        organization
        |> Organization.update_changeset(params)
        |> Repo.update()
        |> case do
          {:ok, updated_org} ->
            {:ok, updated_org}
          error -> error
        end
    end
  end

  def update_organization_alarm_settings(id, params) do
    Repo.get(Organization, id)
    |> case do
      nil ->
        {:error, "not_found"}

      organization ->
        organization
        |> Organization.alarm_settings_changeset(params)
        |> Repo.update()
        |> case do
          {:ok, updated_org} ->
            {:ok, updated_org}
          error -> error
        end
    end
  end

  def create_user_organization(params) do
    %UserOrganization{}
    |> UserOrganization.changeset(params)
    |> Repo.insert()
  end

  def update_user_organization(user_id, organization_id, role_id) do
    from(uo in UserOrganization,
      where: uo.user_id == ^user_id and uo.organization_id == ^organization_id
    )
    |> Repo.update_all(set: [role_id: role_id])
  end

  def get_user_organization(user_id, organization_id) do
    Repo.get_by(UserOrganization, user_id: user_id, organization_id: organization_id)
  end

  def get_users_of_organization(organization_id) do
    from(uo in UserOrganization, where: uo.organization_id == ^organization_id)
    |> Repo.all()
    |> Repo.preload(user: [:user_organizations])
  end

  def delete_organization(organization_id, is_active) do
    [organization] = get_organizations([organization_id])
    organization_users = get_users_of_organization(organization_id) |> Enum.map(& &1.user)

    Multi.new()
    |> update_organization_status(organization, is_active)
    |> update_users_organizations_status(organization_id, is_active)
    |> handle_users_on_org_deactivation(organization_id, organization_users, is_active)
    |> Repo.transaction()
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def remove_user_from_organization(user_id, organization_id) do
    user = Accounts.get_user(user_id)

    multi =
      Multi.new()
      |> Multi.update_all(
        :update_users_orgs_active,
        from(uo in UserOrganization,
          where: uo.organization_id == ^organization_id and uo.user_id == ^user_id
        ),
        set: [status: "Archived"]
      )

    case user.user_organizations do
      [_first, _second | _other] when user.organization_id == organization_id ->
        organization =
          Enum.find(
            user.user_organizations,
            &(&1.organization_id != organization_id && &1.org_status != :deleted &&
                &1.status != "Archived")
          )

        multi
        |> switch_organization_by_multi(user, organization)

      _ ->
        multi
    end
    |> Repo.transaction()
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def active_user_in_organization(user_id, organization_id) do
    user = Accounts.get_user(user_id)

    multi =
      Multi.new()
      |> Multi.update_all(
        :update_users_orgs_active,
        from(uo in UserOrganization,
          where: uo.organization_id == ^organization_id and uo.user_id == ^user_id
        ),
        set: [status: "Active"]
      )

    # ["dycoders", "IZ"]
    # organization =
    #   if length(user.user_organizations) > 1,
    #     do:
    #       Enum.find(
    #         user.user_organizations,
    #         &(&1.organization_id == organization_id)
    #       )
    all_archived? = Enum.all?(user.user_organizations, &(&1.status == "Archived"))

    case {all_archived?, user.user_organizations} do
      {true, [_first, _second | _other]} ->
        organization =
          Enum.find(
            user.user_organizations,
            &(&1.organization_id == organization_id)
          )

        multi
        |> switch_organization_by_multi(user, organization)

      _ ->
        multi
    end
    # multi
    # |> switch_organization_by_multi(user, organization)
    |> Repo.transaction()
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def get_organization_by_name(name) do
    Repo.get_by(Organization, name: name)
  end

  defp update_organization_status(multi, organization, is_active) do
    multi
    |> Multi.update(
      :update_org,
      Organization.update_changeset(organization, %{is_active: is_active})
    )
  end

  # defp update_users_organizations_status(multi, org_id, true) do
  #   multi
  #   |> Multi.update_all(
  #     :update_users_orgs_active,
  #     from(uo in UserOrganization, where: uo.organization_id == ^org_id),
  #     set: [org_status: :active]
  #   )
  # end

  defp update_users_organizations_status(multi, org_id, false) do
    multi
    |> Multi.update_all(
      :update_users_orgs_active,
      from(uo in UserOrganization, where: uo.organization_id == ^org_id),
      set: [org_status: :deleted]
    )
  end

  defp handle_users_on_org_deactivation(multi, organization_id, organization_users, false) do
    Enum.reduce(organization_users, multi, fn user, multi ->
      case user.user_organizations do
        [_first, _second | _other] when user.organization_id == organization_id ->
          organization =
            Enum.find(
              user.user_organizations,
              &(&1.organization_id != organization_id && &1.org_status != :deleted)
            )

          multi
          |> switch_organization_by_multi(user, organization)

        _ ->
          multi
      end
    end)
  end

  defp switch_organization_by_multi(multi, user, nil), do: multi

  defp switch_organization_by_multi(multi, user, organization) do
    multi
    |> Multi.update(
      "switch_user_#{organization.organization_id}",
      Accounts.User.organization_changeset(user, %{
        organization_id: organization.organization_id
      })
    )
  end

  def delete_all_organizations_except() do
    Repo.transaction(fn ->
      # Find users who will be removed from organizations
      users_to_update = from(u in "users",
        join: uo in "users_organizations",
        on: uo.user_id == u.id,
        where: uo.organization_id not in [884, 813],
        where: not exists(
          from uo2 in "users_organizations",
          select: 1,
          where: uo2.user_id == fragment("u0.id") and uo2.organization_id in [884, 813]
        ),
        select: u.id
      ) |> Repo.all()

      # First delete all sensor data for devices in organizations to be deleted
      from(sd in "sensors_data",
        join: s in "sensors",
        on: sd.sensor_id == s.id,
        join: d in "devices",
        on: s.device_id == d.id,
        where: d.organization_id != 884 and d.organization_id != 813
      )
      |> Repo.delete_all()

      # Delete all sensors for devices in organizations to be deleted
      from(s in "sensors",
        join: d in "devices",
        on: s.device_id == d.id,
        where: d.organization_id != 884 and d.organization_id != 813
      )
      |> Repo.delete_all()

      # Delete all commands queue entries for devices in organizations to be deleted
      from(cq in "commands_queue",
        join: d in "devices",
        on: cq.device_id == d.id,
        where: d.organization_id != 884 and d.organization_id != 813
      )
      |> Repo.delete_all()

      # Update devices to remove user references for users being removed
      from(d in Atlas.Devices.Device,
        where: d.user_id in ^users_to_update
      )
      |> Repo.update_all(set: [user_id: nil])

      # Delete all devices in organizations to be deleted
      from(d in "devices",
        where: d.organization_id != 884 and d.organization_id != 813
      )
      |> Repo.delete_all()

      # Delete auth methods for users being removed from organizations
      from(uam in "users_auth_methods",
        where: uam.user_id in ^users_to_update
      )
      |> Repo.delete_all()

      # Delete all user organizations for organizations to be deleted
      from(uo in "users_organizations",
        where: uo.organization_id != 884 and uo.organization_id != 813
      )
      |> Repo.delete_all()

      # Delete all reports for organizations to be deleted
      from(r in "reports",
        where: r.organization_id != 884 and r.organization_id != 813
      )
      |> Repo.delete_all()

      # Delete all invite tokens for organizations to be deleted
      from(it in "invite_tokens",
        where: it.organization_id != 884 and it.organization_id != 813
      )
      |> Repo.delete_all()

      # Finally delete all organizations except the specified ones
      from(o in "organizations",
        where: o.id != 884 and o.id != 813
      )
      |> Repo.delete_all()

      %{status: "success", message: "Successfully deleted all organizations except 884 and 813"}
    end)
  end
end

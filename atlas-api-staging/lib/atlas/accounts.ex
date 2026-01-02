defmodule Atlas.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Atlas.{Repo, Profile, Message, Buyer}
  alias Ecto.Multi

  alias Atlas.Accounts.{User, UserToken, InviteToken, UserNotifier, UsersAuthMethod}
  alias Atlas.Organizations.UserOrganization

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email) |> Repo.preload(:profile)
  end

  def get_user_by_identifier(identifier) when is_binary(identifier) do
    Repo.get_by(User, apple_identifier: identifier)
  end

  def verify_token(token) do
    binary_token = Base.url_decode64!(token, padding: false)

    token_exists? =
      from(u in UserToken, where: u.token == ^binary_token and u.context == "session")
      |> Repo.exists?()

    if token_exists? do
      user = get_user_by_session_token(binary_token)

      {:ok, user}
    else
      {:error, "error"}
    end
  end

  def get_users(organization_id, current_user) do
    base_query = from(u in User,
      join: uo in assoc(u, :user_organizations),
      where: uo.organization_id == ^organization_id,
      preload: [:profile, :organization, user_organizations: [:organization, role: [rules: [:resource]]]])

    # Get current user's role
    current_user_org = Repo.get_by(UserOrganization,
      user_id: current_user.id,
      organization_id: organization_id
    )

    query = case current_user_org.role.role do
      "super_admin" ->
        # Super admin sees all users
        base_query

      "admin" ->
        # Admin sees users they created or themselves
        from [u, uo] in base_query,
          where: u.created_by_id == ^current_user.id or u.id == ^current_user.id

      _ ->
        # Regular users see only themselves
        from [u, uo] in base_query,
          where: u.id == ^current_user.id
    end

    Repo.all(query)
  end

  def get_user_role(user_id, organization_id) do
    query =
      from uo in UserOrganization,
        join: r in Acl.ACL.Role,
        on: uo.role_id == r.id,
        where: uo.user_id == ^user_id and uo.organization_id == ^organization_id,
        select: r

    Repo.one(query)
  end

  def update_user_active_organization(user, organization_id) do
    user
    |> Ecto.Changeset.change(organization_id: organization_id)
    |> Repo.update()
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    query = from u in User,
      distinct: true,
      join: uo in assoc(u, :user_organizations),
      join: org in assoc(uo, :organization),
      where: u.email == ^email and u.is_active == true and org.is_active == true ,
      limit: 1,
      preload: [:profile, user_organizations: [:organization, role: [rules: [:resource]]]]

    case Repo.one(query) do
      nil -> nil
      user -> if User.valid_password?(user, password), do: user
    end
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id) |> Repo.preload(:profile)

  def get_user(id),
    do:
      Repo.get(User, id)
      |> Repo.preload([:profile, :user_organizations, user_organizations: [:organization, role: [rules: [:resource]]]])

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """

  def register_user(attrs) do
    InviteToken.validate_invite_token(attrs["token"])
    |> case do
      {:ok, :without_token_sign_up} ->
        do_register_user(attrs, {"super_admin", nil, nil})

      {:ok, invite_token} ->
        attrs
        |> Map.put("organization_id", invite_token.organization_id)
        |> do_register_user({invite_token.role_id, invite_token.organization_id, invite_token})

      error ->
        error
    end
  end

  def do_register_user(attrs, {_role, organization_id, invite_token}) do
    Multi.new()
    |> Multi.insert(:user, User.registration_changeset(%User{}, attrs))
    |> Multi.run(:roles, fn _repo, %{user: user} ->
      if organization_id do
        {:ok, []}
      else
        {:ok, Atlas.Roles.create_default_roles_and_rules(user.organization_id)}
      end
    end)
    |> Multi.insert(:user_auth_method, fn %{user: user} ->
      %UsersAuthMethod{}
      |> UsersAuthMethod.changeset(%{user_id: user.id, auth_method_name: "email"})
    end)
    |> Multi.run(:user_organization, fn _repo, %{user: user, roles: roles} ->
      role =
        Enum.find(roles, fn role -> role.role == "super_admin" end) ||
          Atlas.Roles.get_role_by_organization_id(user.organization_id, "super_admin")

      %UserOrganization{}
      |> UserOrganization.changeset(%{
        user_id: user.id,
        organization_id: organization_id || user.organization_id,
        role_id: (invite_token && invite_token.role_id) || role.id,
        status: "Active",
        is_creator: if(invite_token, do: false, else: true)
      })
      |> Repo.insert()
    end)
    |> Multi.run(:invite, fn _repo, %{user: user, roles: roles} ->
      if invite_token do
        InviteToken.mark_as_used(invite_token.token)
      else
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} ->
        {:ok,
         user
         |> Repo.preload([
           :profile,
           user_organizations: [:organization, role: [rules: [:resource]]]
         ])}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def create_user_from_invite(user, invite_struct) do
    Multi.new()
    |> Multi.insert(
      :create_user_organization,
      UserOrganization.changeset(%UserOrganization{}, %{
        user_id: user.id,
        organization_id: invite_struct.organization_id,
        role_id: invite_struct.role_id,
        status: "Active"
      })
    )
    |> Multi.update(:user, fn %{create_user_organization: user_organization} ->
      Ecto.Changeset.change(user, organization_id: user_organization.organization_id)
    end)
    |> Multi.run(:mark_invite_token_used, fn _repo, _changes ->
      InviteToken.mark_as_used(invite_struct.token)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} ->
        {:ok, user}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def register_user_by_social(%{provider: provider, info: %{name: name, email: email}} = auth) do
    attrs = %{"first_name" => name, "email" => email}

    case Repo.get_by(User, email: email) do
      nil ->
        Multi.new()
        |> Multi.insert(
          :user,
          User.registration_changeset(%User{}, attrs, password: false)
        )
        |> Multi.run(:roles, fn _repo, %{user: user} ->
          {:ok, Atlas.Roles.create_default_roles_and_rules(user.organization_id)}
        end)
        |> Multi.insert(:user_auth_method, fn %{user: user} ->
          %UsersAuthMethod{}
          |> UsersAuthMethod.changeset(%{
            user_id: user.id,
            auth_method_name: Atom.to_string(provider)
          })
        end)
        |> Multi.run(:user_organization, fn _repo, %{user: user, roles: roles} ->
          role = Enum.find(roles, fn role -> role.role == "super_admin" end)

          %UserOrganization{}
          |> UserOrganization.changeset(%{
            user_id: user.id,
            organization_id: user.organization_id,
            role_id: role.id,
            status: "Active"
          })
          |> Repo.insert()
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{user: user}} ->
            {:ok, user}

          {:error, changeset} ->
            {:error, changeset}
        end

      user ->
        Repo.get_by(UsersAuthMethod, user_id: user.id, auth_method_name: Atom.to_string(provider))
        |> case do
          nil ->
            params = %{
              user_id: user.id,
              provider_user_id: auth.uid,
              auth_method_name: Atom.to_string(provider)
            }

            %UsersAuthMethod{}
            |> UsersAuthMethod.changeset(params)
            |> Repo.insert()

            {:ok, user}

          _ ->
            {:ok, user}
        end
    end
  end

  def register_user_by_social(attrs) do
    case %User{}
         |> User.social_registration_changeset(attrs)
         |> Repo.insert() do
      {:ok, user} ->
        user = Repo.preload(user, :profile)
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def register_user_by_apple(attrs) do
    case %User{}
         |> User.apple_registration_changeset(attrs)
         |> Repo.insert() do
      {:ok, user} ->
        user = Repo.preload(user, :profile)
        {:ok, user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Creates a new user with the given attributes.

  ## Examples

      iex> create_user(%{email: "user@example.com", password: "password", first_name: "John", last_name: "Doe"})
      {:ok, %User{}}

      iex> create_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updated a user profile

  ## Examples

      iex> update_users_profile(%{field: value})
      {:ok, %User{}}

      iex> update_users_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_users_profile(user, attrs) do
    user
    |> Profile.changeset(attrs)
    |> Repo.insert_or_update()
    |> case do
      {:ok, profile} ->
        map_of_profile =
          profile
          |> Map.from_struct()
          |> Map.drop([
            :__meta__,
            :inserted_at,
            :updated_at
          ])

        if Enum.any?(map_of_profile, fn {_key, value} -> value == nil end) do
          Ecto.Changeset.change(profile, is_completed: false) |> Repo.update()
        else
          Ecto.Changeset.change(profile, is_completed: true) |> Repo.update()
        end

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def update_user_password2(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    from(user in Atlas.Accounts.User,
      where: user.id in subquery(query),
      preload: [
        :organization,
        user_organizations:
          ^from(uo in Atlas.Organizations.UserOrganization,
            where: uo.status == "Active" and uo.org_status == :active,
            preload: [role: [rules: [:resource]]]
          )
      ]
    )
    |> Repo.one()
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  def delete_old_otp_if_exists(user) do
    from(t in UserToken,
      where: t.user_id == ^user.id and t.context in ["reset_password_request", "verified"]
    )
    |> Repo.delete_all()
  end

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user) do
    {otp, user_token} = UserToken.build_email_token(user, "reset_password_request")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, otp)
    otp
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def update_otp_status(id, otp, context) do
    token =
      from(u in UserToken,
        where: u.user_id == ^id and u.otp == ^otp and u.context == ^context
      )
      |> Repo.one!()

    changeset = Ecto.Changeset.change(token, context: "verified")
    Repo.update(changeset)
  end

  def verify_otp(id, otp, context) do
    from(u in UserToken,
      where: u.user_id == ^id and u.otp == ^otp and u.context == ^context
    )
    |> Repo.exists?()
  end

  def verify_otp_status(id, context) do
    from(u in UserToken,
      where: u.user_id == ^id and u.context == ^context
    )
    |> Repo.exists?()
  end

  def verify_email_change(%{"email" => email} = params, current_email) do
    if email == current_email do
      Map.drop(params, ["email", "user_id"])
    else
      params
    end
  end

  def deleteAccount(user_id) do
    expiration_date = ~D[2020-05-05] |> NaiveDateTime.new(~T[00:00:00])

    Repo.transaction(fn ->
      # Fetch the user's current email
      user = Repo.get(User, user_id)
      updated_email = "#{user.email}lorem"
      # Update the email field in the User table
      from(u in User, where: u.id == ^user_id)
      |> Repo.update_all(set: [email: updated_email])

      # Update the fields in the Profile table
      from(p in Profile, where: p.user_id == ^user_id)
      |> Repo.update_all(
        set: [
          agent_email: "lorem",
          image_url: "lorem",
          first_name: "lorem",
          last_name: "lorem",
          phone_number_primary: "lorem",
          brokerage_name: "lorem",
          brokerage_lisence_no: "lorem",
          lisence_id_no: "lorem",
          broker_street_address: "lorem",
          broker_city: "lorem",
          brokerage_state: "lorem",
          brokerage_zip_code: "lorem"
        ]
      )

      # Update the content field in the Messages table
      from(m in Message, where: m.sent_by == ^user_id)
      |> Repo.update_all(set: [content: "lorem"])

      case expiration_date do
        {:ok, naive_date_time} ->
          utc_expiration_date = DateTime.from_naive!(naive_date_time, "Etc/UTC")

          # Set the buyer expiration date to a past date for the user's buyer cards
          from(b in Buyer, where: b.user_id == ^user_id)
          |> Repo.update_all(set: [buyer_expiration_date: utc_expiration_date])

        {:error, _reason} ->
          raise "Invalid date format"
      end
    end)
  end

  def email_for_organization(email, organization_id) do
    with {:exists_in_system?, %User{id: id}} <- {:exists_in_system?, get_user_by_email(email)},
         {:exists_in_organization?, %{}} <-
           {:exists_in_organization?,
            Atlas.Organizations.get_user_organization(id, organization_id)} do
      :exists
    else
      {:exists_in_system?, nil} -> :not_in_system
      {:exists_in_organization?, nil} -> :not_in_org
    end
  end

  def get_user_by_id(user_id) do
    Repo.get!(User, user_id) |> Repo.preload(:profile)
  end

  def verify_email_change(params, _current_email), do: params

  # Helper function to get user with role info
  def get_user_with_role(user_id, organization_id) do
    from(u in User,
      join: uo in assoc(u, :user_organizations),
      where: u.id == ^user_id and uo.organization_id == ^organization_id,
      select: %{
        id: u.id,
        email: u.email,
        first_name: u.first_name,
        last_name: u.last_name,
        created_by_id: u.created_by_id,
        organization_id: uo.organization_id,
        role: uo.role
      })
    |> Repo.one()
  end

  # Helper function to check if user is creator of another user
  def is_creator?(creator_id, user_id) do
    from(u in User,
      where: u.id == ^user_id and u.created_by_id == ^creator_id,
      select: count(u.id) > 0)
    |> Repo.one()
  end

  @doc """
  Creates a user organization association with the given attributes.
  """
  def create_user_organization(user_id, organization_id, role_id) do
    role_id =
      case role_id do
        %Acl.ACL.Role{id: id} -> id
        id when is_integer(id) -> id
        _ -> Atlas.Roles.get_role_by_organization_name(organization_id, "user").id
      end
    %Atlas.Organizations.UserOrganization{}
    |> Atlas.Organizations.UserOrganization.changeset(%{
      user_id: user_id,
      organization_id: organization_id,
      role_id: role_id,
      status: "Active"
    })
    |> Repo.insert()
  end

  def create_user_in_organization(attrs, creator, organization_id) do
    Repo.transaction(fn ->
      with {:ok, user} <- create_user(%{
             email: attrs["email"],
             password: attrs["password"],
             first_name: attrs["first_name"],
             last_name: attrs["last_name"],
             created_by_id: creator,
             organization: organization_id,
             organization_id: organization_id
           }),
           # Create default roles for the organization after user is created
           {:ok, _roles} <- {:ok, Atlas.Roles.create_default_roles_and_rules(organization_id)},
           {:ok, _user_org} <- create_user_organization(user.id, organization_id, Atlas.Roles.get_role_by_organization_name(organization_id, attrs["role"] || "user")) do
        {:ok, user}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def update_user_if_authorized(user_id, attrs, current_user) do
    user = get_user!(user_id)

    if can_modify_user?(current_user, user) do
      user
      |> User.changeset(attrs)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  # Helper function to check if user can modify another user
  defp can_modify_user?(current_user, target_user) do
    current_user_org = get_user_organization(current_user.id, target_user.organization_id)

    case current_user_org.role.role do
      "super_admin" -> true
      "admin" -> current_user.id == target_user.created_by_id || current_user.id == target_user.id
      _ -> current_user.id == target_user.id
    end
  end

  def get_user_organization(user_id, organization_id) do
    from(uo in UserOrganization,
      where: uo.user_id == ^user_id and uo.organization_id == ^organization_id)
    |> Repo.one()
    |> case do
      nil -> nil
      user_org -> Repo.preload(user_org, :role)
    end
  end

  @doc """
  Checks if a user is active in a specific organization.

  ## Examples

      iex> active_user_in_organization(user_id, organization_id)
      true

      iex> active_user_in_organization(user_id, organization_id)
      false

  """
  def active_user_in_organization(user_id, organization_id) do
    from(uo in UserOrganization,
      where: uo.user_id == ^user_id and
             uo.organization_id == ^organization_id and
             uo.status == "Active")
    |> Repo.exists?()
  end

def get_dashboard_stats(user_id, role, organization_id, name) do
  case role do
    "super_admin" ->
      %{
        total_devices: Repo.aggregate(
          from(d in Atlas.Devices.Device, where: is_nil(d.deleted_at)), :count, :id
        ),
        device_locations: Repo.all(from d in Atlas.Devices.Device,  where: is_nil(d.deleted_at), select: %{latitude: d.latitude, longitude: d.longitude, name: d.name}),
        total_users:
          from(u in User,
            join: uo in assoc(u, :user_organizations),
            join: r in assoc(uo, :role),
            where: r.role == "admin",
            where: u.created_by_id == ^user_id,
            select: count(u.id)
          )
          |> Repo.one(),
          role: role,
          name: name
      }

    "admin" ->
      user_ids = Repo.all(from u in User, where: u.organization_id == ^organization_id, where: u.created_by_id == ^user_id, select: u.id)
      %{
        total_devices: Repo.aggregate(
          from(d in Atlas.Devices.Device, where: d.organization_id == ^organization_id), :count, :id
        ),
        device_locations: Repo.all(
          from d in Atlas.Devices.Device, where: d.organization_id == ^organization_id, select: %{latitude: d.latitude, longitude: d.longitude}
        ),
        total_users: length(user_ids),
        role: role,
        name: name
      }

    _ -> # regular user
      %{
        total_devices: Repo.aggregate(
          from(d in Atlas.Devices.Device, where: d.user_id == ^user_id), :count, :id
        ),
        device_locations: Repo.all(
          from d in Atlas.Devices.Device, where: d.user_id == ^user_id, select: %{latitude: d.latitude, longitude: d.longitude}
        ),
        user_count: 1,
        role: role,
        name: name
      }
  end
end

def get_users_by_role(organization_id, current_user) do
  case get_user_role_name(current_user, organization_id) do
    "super_admin" ->
      # Return all users with admin role (across all orgs)
      from(u in User,
        join: uo in assoc(u, :user_organizations),
        join: r in assoc(uo, :role),
        where: r.role == "admin",
        preload: [:profile, :organization, user_organizations: [:organization, role: [rules: [:resource]]]]
      )
      |> Repo.all()

    "admin" ->
      # Return all users with user role in the same org
      from(u in User,
        join: uo in assoc(u, :user_organizations),
        join: r in assoc(uo, :role),
        where: uo.organization_id == ^organization_id and r.role == "user",
        where: u.created_by_id == ^current_user.id,
        preload: [:profile, :organization, user_organizations: [:organization, role: [rules: [:resource]]]]
      )
      |> Repo.all()

    _ ->
      # Regular users see only themselves
      from(u in User,
        where: u.id == ^current_user.id,
        preload: [:profile, :organization, user_organizations: [:organization, role: [rules: [:resource]]]]
      )
      |> Repo.all()
  end
end

defp get_user_role_name(current_user, organization_id) do
  # Assumes user_organizations is preloaded or you can fetch it here
  uo =
    UserOrganization
    |> Repo.get_by(user_id: current_user.id, organization_id: organization_id)
    |> Repo.preload(:role)

  if uo && uo.role, do: uo.role.role, else: nil
end

def get_all_users_with_organization_and_role(organization_id, user_id) do
  from(u in User,
    join: uo in assoc(u, :user_organizations),
    join: org in assoc(uo, :organization),
    join: r in assoc(uo, :role),
    where: u.created_by_id == ^user_id,
    preload: [
      user_organizations: [:organization, :role]
    ],
    select: u
  )
  |> Repo.all()
end
def delete_users_and_organizations_with_nil_role_except_201 do
  user_ids_in_user_org =
    from(uo in Atlas.Organizations.UserOrganization, select: uo.user_id)
    |> Repo.all()
    |> Enum.uniq()

  # 2. Delete all users whose id is NOT in that list
  from(u in User, where: u.id not in ^user_ids_in_user_org)
  |> Repo.delete_all()

  org_ids_in_user_org =
    from(uo in Atlas.Organizations.UserOrganization, select: uo.organization_id)
    |> Repo.all()
    |> Enum.uniq()

  # 2. Delete all organizations whose id is NOT in that list
  from(o in Atlas.Organizations.Organization, where: o.id not in ^org_ids_in_user_org)
  |> Repo.delete_all()

  {:ok, "Deleted users and organizations with nil role (except user 201)"}
end

def delete_users_with_no_role_and_empty_organizations do
  # 1. Find all user_ids where all their user_organizations have nil role_id
  user_ids =
    from(u in User,
      left_join: uo in assoc(u, :user_organizations),
      group_by: u.id,
      having: fragment("bool_and(?)", is_nil(uo.role_id)),
      select: u.id
    )
    |> Repo.all()

  # 2. Delete those users
  {user_count, _} =
    from(u in User, where: u.id in ^user_ids)
    |> Repo.delete_all()

  # 3. Find all organization_ids that have no user_organizations
  org_ids =
    from(o in Atlas.Organizations.Organization,
      left_join: uo in assoc(o, :user_organizations),
      group_by: o.id,
      having: count(uo.id) == 0,
      select: o.id
    )
    |> Repo.all()

  # 4. Delete those organizations
  {org_count, _} =
    from(o in Atlas.Organizations.Organization, where: o.id in ^org_ids)
    |> Repo.delete_all()

  {user_count, org_count}
end

def do_create_user(attrs, {role, organization_id}) do
  Multi.new()
  |> Multi.insert(:user, User.registration_changeset(%User{}, attrs))
  |> Multi.run(:roles, fn _repo, %{user: user} ->
    if organization_id do
      {:ok, Atlas.Roles.get_roles(organization_id)}
    else
      {:ok, Atlas.Roles.create_default_roles_and_rules(user.organization_id)}
    end
  end)
  |> Multi.insert(:user_auth_method, fn %{user: user} ->
    %UsersAuthMethod{}
    |> UsersAuthMethod.changeset(%{user_id: user.id, auth_method_name: "email"})
  end)
  |> Multi.run(:user_organization, fn _repo, %{user: user, roles: roles} ->
    role =
      Enum.find(roles, fn r -> r.role == role end)

    %UserOrganization{}
    |> UserOrganization.changeset(%{
      user_id: user.id,
      organization_id: organization_id || user.organization_id,
      role_id: role.id,
      status: "Active",
      is_creator: true
    })
    |> Repo.insert()
  end)
  |> Repo.transaction()
  |> case do
    {:ok, %{user: user}} ->
      {:ok,
       user
       |> Repo.preload([
         :profile,
         user_organizations: [:organization, role: [rules: [:resource]]]
       ])}

    {:error, _, changeset, _} ->
      {:error, changeset}
  end
end

def update_user_active_status(user_id, is_active) do
  case Repo.get(User, user_id) do
    nil -> {:error, :not_found}
    user ->
      user
      |> Ecto.Changeset.change(%{is_active: is_active})
      |> Repo.update()
  end
end

def deactivate_all_users_in_organization(organization_id) do
  from(u in User,
    join: uo in assoc(u, :user_organizations),
    where: uo.organization_id == ^organization_id)
  |> Repo.update_all(set: [is_active: false])
end

def activate_all_users_in_organization(organization_id) do
  from(u in User,
    join: uo in assoc(u, :user_organizations),
    where: uo.organization_id == ^organization_id)
  |> Repo.update_all(set: [is_active: true])
end



end

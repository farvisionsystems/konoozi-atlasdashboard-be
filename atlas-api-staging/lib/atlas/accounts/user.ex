defmodule Atlas.Accounts.User do
  use Ecto.Schema
  use Arc.Ecto.Schema
  import Ecto.Changeset

  alias Atlas.{
    Buyer,
    Repo,
    Buyers,
    Thread,
    Accounts.AuthProvider,
    Profile,
    Organizations.Organization
  }

  @derive {Jason.Encoder,
           only: [
             :id,
             :email,
             :password,
             :hashed_password,
             :confirmed_at,
             :favourite_buyers,
             :profile,
             :first_name,
             :last_name,
             :created_by_id,
             :is_active
           ]}
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :apple_identifier, :string
    field :favourite_buyers, {:array, :integer}, default: []
    field :first_name, :string
    field :last_name, :string
    field :is_active, :boolean, default: true

    many_to_many(:threads, Thread,
      join_through: "threads_users",
      on_replace: :delete
    )

    belongs_to(:organization, Organization)
    has_many(:user_organizations, Atlas.Organizations.UserOrganization)
    has_one(:profile, Atlas.Profile)
    has_many(:buyers, Buyer)
    has_many(:notes, Atlas.Note)
    has_many :auth_providers, AuthProvider
    belongs_to :creator, Atlas.Accounts.User, foreign_key: :created_by_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :first_name, :last_name, :created_by_id, :is_active])
    |> validate_required([:email, :password, :first_name])
    |> update_change(:email, &String.downcase/1)
    |> validate_email(opts)
    |> validate_password(opts)
    |> maybe_cast_organization(attrs)
    |> foreign_key_constraint(:created_by_id)
  end

  def social_registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    # Allow profile to be created
    |> cast_assoc(:profile, required: false, with: &profile_changeset/2)
    |> then(fn changeset ->
      changeset
      |> put_assoc(:auth_providers, [
        %AuthProvider{
          provider: "google"
        }
      ])
      |> put_assoc(:profile, %Profile{
        first_name: Map.get(attrs, "first_name"),
        last_name: Map.get(attrs, "last_name")
      })
    end)
    |> validate_email(opts)
  end

  def apple_registration_changeset(user, attrs, opts \\ [])

  def apple_registration_changeset(user, attrs, _opts) do
    user
    |> cast(attrs, [:email, :apple_identifier])
    # Allow profile to be created
    |> cast_assoc(:profile, required: false, with: &profile_changeset/2)
    |> then(fn changeset ->
      changeset
      |> put_assoc(:auth_providers, [
        %AuthProvider{
          provider: "apple",
          apple_identifier: Map.get(attrs, "apple_identifier")
        }
      ])
      |> put_assoc(:profile, %Profile{
        first_name: Map.get(attrs, "first_name"),
        last_name: Map.get(attrs, "last_name")
      })
    end)
  end

  def generate_password(length \\ 20) do
    :crypto.strong_rand_bytes(length) |> Base.encode64() |> binary_part(0, length)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email, message: "Email already exists. Sign-in instead.")

    # |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    if Keyword.get(opts, :password, true) do
      changeset
      |> validate_required([:password])
      |> validate_length(:password, min: 8, max: 72)
      # Examples of additional password validation:
      # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
      # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
      |> validate_format(:password, ~r/[!@#$%^&*(),.?":{}|<>]/,
        message: "at least one special character"
      )
      |> maybe_hash_password(opts)
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Atlas.Repo)
      |> unique_constraint(:email, message: "Email already exists. Sign-in instead.")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(
        %Atlas.Accounts.User{hashed_password: hashed_password},
        password
      )
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  def get_users_favourite_buyers(id) do
    user = Repo.get(__MODULE__, id)
    Enum.map(user.favourite_buyers, &Buyers.get_buyer(&1))
  end

  def get_favourite_buyers_count(user_id) do
    get_users_favourite_buyers(user_id) |> Enum.count()
  end

  def update_buyers_favourite(user_id, buyer_id, is_favourite) do
    user = Repo.get(__MODULE__, user_id)
    favourite_buyers = user.favourite_buyers

    changeset =
      if is_favourite do
        favourite_buyers = (favourite_buyers ++ [buyer_id]) |> Enum.uniq()
        Ecto.Changeset.change(user, favourite_buyers: favourite_buyers)
      else
        favourite_buyers = (favourite_buyers -- [buyer_id]) |> Enum.uniq()
        Ecto.Changeset.change(user, favourite_buyers: favourite_buyers)
      end

    Repo.update(changeset)
  end

  defp profile_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:first_name, :last_name])
    |> validate_required([:first_name, :last_name])
  end

  defp maybe_cast_organization(changeset, attrs) do
    case Map.get(attrs, "organization_id") do
      nil ->
        case Map.get(attrs, "organization") do
          nil ->
            # If both organization_id and organization are nil, set organization_id to nil
            changeset |> Ecto.Changeset.put_change(:organization_id, nil)
          org ->
            changeset
            |> put_assoc(:organization, %Organization{
              name:
                cond do
                  is_binary(org) -> org
                  is_map(org) and Map.has_key?(org, "name") -> org["name"]
                  true -> String.downcase(to_string(Map.get(attrs, "first_name", ""))) <>
                    Integer.to_string(:rand.uniform(1000))
                end
            })
        end

      organization_id ->
        changeset |> Ecto.Changeset.put_change(:organization_id, organization_id)
    end
  end

  def organization_changeset(user, attrs) do
    user
    |> cast(attrs, [:organization_id])
    |> validate_required([:organization_id])
    |> case do
      %{changes: %{organization_id: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :organization_id, "did not change")
    end
  end



  @doc """
  Creates a new user with the given attributes and creator.

  ## Examples

      iex> create_user(%{email: "user@example.com", password: "password123!"})
      {:ok, %User{}}

      iex> create_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def create_user(attrs \\ %{}, creator \\ nil) do
    attrs = if creator, do: Map.put(attrs, "created_by_id", creator.id), else: attrs
    %__MODULE__{}
    |> registration_changeset(attrs)
    |> Repo.insert()
  end

  defp maybe_add_creator(attrs, creator) do
    attrs = if creator, do: Map.put(attrs, "created_by_id", creator.id), else: attrs
    attrs
  end
end

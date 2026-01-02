defmodule Atlas.Accounts.InviteToken do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Atlas.{Repo, Accounts, Organizations.Organization}

  schema "invite_tokens" do
    field :token, :string
    field :email, :string
    field :expires_at, :naive_datetime
    field :used, :boolean, default: false

    belongs_to(:role, Acl.ACL.Role,
      references: :id,
      foreign_key: :role_id
    )

    belongs_to :organization, Organization

    timestamps()
  end

  @doc false
  def changeset(invite_token, attrs) do
    invite_token
    |> cast(attrs, [:token, :email, :organization_id, :expires_at, :used, :role_id])
    |> validate_required([:token, :email, :expires_at, :role_id])
    |> unique_constraint(:token)
  end

  @doc """
  Generate a new invite token with a 1-hour expiration.
  """
  def generate_invite_token(email, role_id, organization_id) do
    Repo.get_by(__MODULE__, email: email, organization_id: organization_id)
    |> case do
      %__MODULE__{} = invite_token ->
        Repo.delete(invite_token)

      _ ->
        nil
    end

    token = :crypto.strong_rand_bytes(16) |> Base.encode64() |> String.replace("/", "")

    # 1 hour expiration
    expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), 3600, :second)

    %__MODULE__{}
    |> changeset(%{
      token: token,
      email: email,
      role_id: role_id,
      organization_id: organization_id,
      expires_at: expires_at
    })
    |> Repo.insert()
    |> case do
      {:ok, record} ->
        {:ok, Repo.preload(record, [:role, :organization])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def validate_invite_token(nil), do: {:ok, :without_token_sign_up}

  def validate_invite_token(token) do
    now = NaiveDateTime.utc_now()

    case Repo.get_by(__MODULE__, token: token) do
      %__MODULE__{used: true} ->
        {:error, "Token already used"}

      %__MODULE__{expires_at: expires_at} when expires_at < now ->
        {:error, "Token expired"}

      %__MODULE__{} = invite_token ->
        {:ok, invite_token |> Repo.preload([:role, :organization])}

      nil ->
        {:error, "Token not found"}
    end
  end

  @doc """
  Mark an invite token as used.
  """
  def mark_as_used(token) do
    Repo.get_by(__MODULE__, token: token)
    |> case do
      %__MODULE__{} = invite_token ->
        invite_token
        |> changeset(%{used: true})
        |> Repo.update()
        |> case do
          {:ok, _updated_invite_token} -> {:ok, :used}
          {:error, _reason} -> {:error, :update_failed}
        end

      nil ->
        {:error, :not_found}
    end
  end

  def get_by_token(token) do
    case Repo.get_by(__MODULE__, token: token, used: false) do
      nil -> :error
      invite_token -> {:ok, invite_token}
    end
  end

  def invited_users(organization_id) do
    now = NaiveDateTime.utc_now()

    from(
      it in __MODULE__,
      where: it.organization_id == ^organization_id and it.used == false
    )
    |> Repo.all()
    |> Repo.preload([:role, :organization])
    |> Enum.map(fn invite_token ->
      status = if invite_token.expires_at < now, do: "Expired", else: "Invited"

      invite_token |> Map.put(:status, status)
    end)
  end
end

defmodule Atlas.Organizations.UserOrganization do
  use Ecto.Schema
  import Ecto.Changeset

  alias Atlas.Organizations.Organization

  @primary_key false
  schema "users_organizations" do
    field :status, :string
    field :is_creator, :boolean, default: false
    field :org_status, Ecto.Enum, values: [:active, :inactive, :deleted], default: :active

    belongs_to(:role, Acl.ACL.Role,
      references: :id,
      foreign_key: :role_id
    )

    belongs_to(:organization, Organization)
    belongs_to(:user, Atlas.Accounts.User)
    timestamps()
  end

  @doc false
  def changeset(user_organization, attrs) do
    user_organization
    |> cast(attrs, [:user_id, :organization_id, :role_id, :status, :is_creator])
    |> validate_required([:user_id, :organization_id, :role_id])
    |> validate_inclusion(:org_status, [:active, :inactive, :deleted])
    |> unique_constraint([:user_id, :organization_id])
  end

  def update_changeset(user_organization, attrs) do
    user_organization
    |> cast(attrs, [:role_id, :status, :is_creator])
    |> validate_required([:role_id])
    |> validate_inclusion(:org_status, [:active, :inactive, :deleted])
    |> unique_constraint([:user_id, :organization_id])
  end
end

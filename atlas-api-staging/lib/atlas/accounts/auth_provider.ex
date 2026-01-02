defmodule Atlas.Accounts.AuthProvider do
  use Ecto.Schema
  import Ecto.Changeset

  schema "auth_providers" do
    field :email, :string
    field :provider, :string
    field :apple_identifier, :string
    field :is_approved, :boolean
    belongs_to :user, Atlas.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(auth_provider, attrs) do
    auth_provider
    |> cast(attrs, [:provider, :apple_identifier, :user_id, :email])
    |> validate_required([:provider, :user_id])
    |> then(fn changeset ->
      if get_change(changeset, :provider) == "password" do
        changeset |> put_change(:is_approved, false)
      else
        changeset |> put_change(:is_approved, true)
      end
    end)
  end
end

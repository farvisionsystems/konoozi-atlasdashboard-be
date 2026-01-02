defmodule Atlas.Accounts.UsersAuthMethod do
  use Ecto.Schema
  import Ecto.Changeset

  alias Atlas.Accounts

  schema "users_auth_methods" do
    field :provider_user_id, :string
    belongs_to(:user, Accounts.User)

    belongs_to(:auth_method, Accounts.AuthMethod,
      references: :name,
      type: :string,
      foreign_key: :auth_method_name
    )

    timestamps()
  end

  @doc false
  def changeset(users_auth_method, attrs) do
    users_auth_method
    |> cast(attrs, [:provider_user_id, :user_id, :auth_method_name])
    |> validate_required([:user_id, :auth_method_name])
  end
end

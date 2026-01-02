defmodule Atlas.Profile do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Atlas.{Accounts.User, BuyerNeed, Repo, Location}

  @derive {Jason.Encoder,
           only: [
             :id,
             :agent_email,
             :image_url,
             :first_name,
             :last_name,
             :phone_number_primary,
             :brokerage_name,
             :brokerage_lisence_no,
             :lisence_id_no,
             :broker_street_address,
             :broker_city,
             :brokerage_state,
             :brokerage_zip_code,
             :is_completed
           ]}
  schema "profiles" do
    field :agent_email, :string
    field :image_url, :string
    field :first_name, :string
    field :last_name, :string
    field :phone_number_primary, :string
    field :brokerage_name, :string
    field :brokerage_lisence_no, :string
    field :lisence_id_no, :string
    field :broker_street_address, :string
    field :broker_city, :string
    field :brokerage_state, :string
    field :brokerage_zip_code, :string
    field :is_completed, :boolean

    belongs_to :user, Atlas.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :image_url,
      :agent_email,
      :first_name,
      :last_name,
      :phone_number_primary,
      :brokerage_name,
      :brokerage_lisence_no,
      :lisence_id_no,
      :broker_street_address,
      :broker_city,
      :brokerage_state,
      :brokerage_zip_code,
      :user_id
    ])
    |> validate_brokerage_zip_code()
    |> validate_required([
      #      :first_name,
      #      :last_name,
      :user_id
    ])
  end

  defp validate_brokerage_zip_code(changeset) do
    brokerage_zip_code = get_field(changeset, :brokerage_zip_code)

    cond do
      brokerage_zip_code && String.length(brokerage_zip_code) != 5 ->
        add_error(changeset, :brokerage_zip_code, "Zip code must be 5 characters long")

      brokerage_zip_code && Repo.get_by(Location, zip_code: brokerage_zip_code) == nil ->
        add_error(changeset, :brokerage_zip_code, "Zip code not found")

      true ->
        changeset
    end
  end
end

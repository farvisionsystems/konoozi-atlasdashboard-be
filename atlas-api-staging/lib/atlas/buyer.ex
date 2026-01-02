defmodule Atlas.Buyer do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Atlas.{Accounts.User, BuyerNeed, Repo, Location}

  @derive {Jason.Encoder,
           only: [
             :id,
             :first_name,
             :last_name,
             :image_url,
             :email,
             :primary_phone_number,
             :buyer_locations_of_interest,
             :additional_requests,
             :buyer_expiration_date,
             :my_buyer,
             :note,
             :sku,
             :user,
             :is_favourite,
             :buyer_need,
             :inserted_at,
             :updated_at
           ]}
  schema "buyers" do
    field :first_name, :string
    field :last_name, :string
    field :image_url, :string
    field :email, :string
    field :primary_phone_number, :string
    field :sku, :string
    field :buyer_locations_of_interest, {:array, :string}
    field :additional_requests, {:array, :string}
    field :buyer_expiration_date, :utc_datetime
    field :my_buyer, :boolean, virtual: true
    field :is_favourite, :boolean, virtual: true
    field :note, :string, virtual: true
    belongs_to :user, User
    has_one(:buyer_need, BuyerNeed, on_replace: :update)
    has_one(:notes, Atlas.Note, on_replace: :update)

    timestamps(type: :utc_datetime)
  end

  def changeset(buyer, attrs) do
    buyer
    |> cast(attrs, [
      :first_name,
      :last_name,
      :image_url,
      :email,
      :primary_phone_number,
      :buyer_locations_of_interest,
      :additional_requests,
      :buyer_expiration_date,
      :user_id
    ])
    |> validate_required([
      :first_name,
      :last_name,
      :buyer_locations_of_interest,
      :buyer_expiration_date
    ])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_length(:buyer_locations_of_interest,
      min: 1,
      message: "must have at least one location of interest"
    )
    # Add this validation
    |> validate_buyer_locations_of_interest()
    |> cast_assoc(:buyer_need, with: &BuyerNeed.changeset/2)
    |> put_sku(attrs)
  end

  defp validate_buyer_locations_of_interest(changeset) do
    buyer_locations_of_interest = get_field(changeset, :buyer_locations_of_interest) || []

    invalid_zip_codes =
      buyer_locations_of_interest
      |> Enum.filter(fn zip_code ->
        Repo.get_by(Location, zip_code: zip_code) == nil
      end)

    if invalid_zip_codes == [] do
      changeset
    else
      add_error(changeset, :buyer_locations_of_interest, "Zip code not found")
    end
  end

  defp put_sku(changeset, attrs) do
    case get_field(changeset, :sku) do
      nil -> put_change(changeset, :sku, generate_unique_sku(attrs, changeset))
      _ -> changeset
    end
  end

  defp generate_unique_sku(attrs, changeset) do
    last_name = get_field(changeset, :last_name) || Map.get(attrs, "last_name", "")
    user_id = get_field(changeset, :user_id) || Map.get(attrs, "user_id", Enum.random(1000..9999))
    buyer_id = changeset.data.id || Enum.random(1000..9999)

    # Fetch user and preload the profile
    agent = Repo.get_by(User, id: user_id) |> Repo.preload(:profile)

    # Check if the user has a profile; otherwise, use the changeset's last_name
    profile_last_name =
      case agent.profile do
        # If profile is nil, fallback to last_name from the changeset
        nil -> last_name
        # If profile exists but last_name is nil
        profile -> profile.last_name || last_name
      end

    unique_agent_id = user_id + 1000
    unique_buyer_id = buyer_id + 1000

    "BB-" <>
      String.slice(String.upcase(profile_last_name), 0, 6) <>
      "-" <>
      Integer.to_string(unique_agent_id) <>
      "#" <>
      Integer.to_string(unique_buyer_id)
  end

  # defp generate_unique_sku do
  #   letter = <<Enum.random(?A..?Z)>>
  #   digits = Enum.random(1000..9999) |> Integer.to_string()
  #   letter <> digits
  # end
end

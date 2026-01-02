defmodule Atlas.Organizations.Organization do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  defmodule ProfileImage do
    @moduledoc "a public image embedded in the profile json"
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field(:url, :string)
      field(:content_type, :string)
    end

    def changeset(profile_image, attrs) do
      cast(profile_image, attrs, [:id, :url, :content_type])
    end
  end

  defmodule Profile do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      embeds_one(:logo, ProfileImage, on_replace: :update)
      embeds_one(:main_image, ProfileImage, on_replace: :update)
    end

    def changeset(%__MODULE__{} = profile, attrs) do
      profile
      |> cast_embed(:logo)
      |> cast_embed(:main_image)
    end
  end

  schema "organizations" do
    field(:name, :string)
    field(:is_active, :boolean, default: true)
    field(:logo, :string)
    field :general_alarm_email_enabled, :boolean, default: true
    field :general_alarm_push_enabled, :boolean, default: true
    field :general_alarm_sms_enabled, :boolean, default: true
    field :general_alarm_location_preference, :boolean, default: false

    has_one(:user, User)
    has_many(:users_organizations, Atlas.Organizations.UserOrganization)

    timestamps(type: :utc_datetime)
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :is_active, :logo, :general_alarm_email_enabled, :general_alarm_push_enabled, :general_alarm_sms_enabled, :general_alarm_location_preference])
    # |> validate_format(:name, ~r/^[a-zA-Z0-9 ]*$/,
    #   message: "Name can only contain letters, numbers, and spaces"
    # )
    |> validate_required([:name])
    # |> update_change(:name, &String.downcase/1)
    # |> unsafe_validate_unique(:name, Atlas.Repo, message: "Organization name already exists")
    # |> unique_constraint(:name, message: "Organization name already exists")
    |> validate_unique_name(organization.id)
  end

  def update_changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :name,
      :is_active,
      :logo,
      :general_alarm_email_enabled,
      :general_alarm_push_enabled,
      :general_alarm_sms_enabled,
      :general_alarm_location_preference
    ])
    # |> validate_format(:name, ~r/^[a-zA-Z0-9 ]*$/,
    #   message: "Name can only contain letters, numbers, and spaces"
    # )
    |> validate_required([:name])
    # |> update_change(:name, &String.downcase/1)
    # |> unsafe_validate_unique(:name, Atlas.Repo)
    # |> unique_constraint(:name, message: "Organization name already exists")
    |> validate_unique_name(organization.id)
  end

  def alarm_settings_changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :general_alarm_email_enabled,
      :general_alarm_push_enabled,
      :general_alarm_sms_enabled,
      :general_alarm_location_preference
    ])
  end

  defp validate_unique_name(changeset, organization_id) do
    changeset
    |> get_field(:name)
    |> normalize_name()
    |> validate_name_uniqueness(changeset, organization_id)
  end

  defp normalize_name(nil), do: nil
  defp normalize_name(name), do: String.downcase(String.trim(name))

  defp validate_name_uniqueness(nil, changeset, _), do: changeset

  defp validate_name_uniqueness(normalized_name, changeset, organization_id) do
    IO.inspect(normalized_name, label: "normalized_name")
    IO.inspect(organization_id, label: "organization_id")
    if case_insensitive_name_exists?(normalized_name, organization_id) do
      add_error(changeset, :name, "Organization name already exists (case-insensitive)")
    else
      changeset
    end
  end

  defp case_insensitive_name_exists?(normalized_name, organization_id) do
    query =
      from o in Atlas.Organizations.Organization,
        where: fragment("LOWER(?) = ?", o.name, ^normalized_name)

    query =
      if organization_id do
        query |> where([o], o.id != ^organization_id)
      else
        query
      end

    Atlas.Repo.exists?(query)
  end
end

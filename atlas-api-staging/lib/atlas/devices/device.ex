defmodule Atlas.Devices.Device do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :gateway_uid, :latitude, :longitude, :serial_number, :mac_address, :auto_region, :model, :name, :status, :organization_id, :model_id, :image, :inserted_at, :updated_at, :user_id, :tb, :sl, :pb, :tr, :rl, :ph, :alarm, :wn, :firmware_version, :alarm_email_enabled, :alarm_push_enabled, :alarm_location_preference, :alarm_notification_email, :alarm_notification_phone, :alarm_sms_enabled]}
  schema "devices" do
    field :deleted_at, :utc_datetime
    field :gateway_uid, :integer
    field :latitude, :decimal
    field :longitude, :decimal
    field :serial_number, :string
    field :mac_address, :string
    field :auto_region, :string
    field :model, :string
    field :name, :string
    field :status, :string, default: "online"
    field :model_id, :id
    field :image, :string
    field :timezone, :string, default: "UTC"
    field :tb, :string
    field :sl, :string
    field :pb, :string
    field :tr, :string
    field :rl, :string
    field :ph, :string
    field :alarm, :integer
    field :wn, :string
    field :firmware_version, :string
    field :alarm_email_enabled, :boolean, default: true
    field :alarm_push_enabled, :boolean, default: true
    field :alarm_location_preference, :boolean, default: false
    field :alarm_notification_email, :string
    field :alarm_notification_phone, :string
    field :alarm_sms_enabled, :boolean, default: false
    belongs_to :user, Atlas.Accounts.User, foreign_key: :user_id
    belongs_to :organization, Atlas.Organizations.Organization, foreign_key: :organization_id

    has_many :sensors, Atlas.Devices.Sensor

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :name,
      :serial_number,
      :organization_id,
      :model,
      :latitude,
      :longitude,
      :status,
      :image,
      :deleted_at,
      :timezone,
      :updated_at,
      :user_id,
      :tb,
      :sl,
      :pb,
      :tr,
      :rl,
      :ph,
      :alarm,
      :wn,
      :firmware_version,
      :mac_address,
      :auto_region,
      :alarm_email_enabled,
      :alarm_push_enabled,
      :alarm_location_preference,
      :alarm_notification_email,
      :alarm_notification_phone,
      :alarm_sms_enabled
    ])
    |> validate_required([:name, :serial_number, :organization_id])
    |> validate_format(:name, ~r/[a-zA-Z]/, message: "must contain at least one letter")
    |> validate_optional_fields()
    |> unsafe_validate_unique([:serial_number, :organization_id], Atlas.Repo,
      query: from(d in __MODULE__, where: is_nil(d.deleted_at))
    )
  end

  defp validate_optional_fields(changeset) do
    changeset
    |> validate_inclusion(:alarm, [0, 1, 2], message: "must be 0, 1, or 2")
    |> validate_format(:firmware_version, ~r/^\d{2}\.\d{2}\.\d{2}[A-Z0-9]$/, message: "must be in format MM.DD.YYX")
    |> validate_length(:tb, is: 3)
    |> validate_length(:sl, is: 3)
    |> validate_length(:pb, is: 3)
    |> validate_length(:tr, is: 3)
    |> validate_length(:rl, is: 3)
    |> validate_length(:ph, is: 3)
    |> validate_length(:wn, max: 24)
    |> validate_email_format()
    |> validate_phone_format()
  end

  defp validate_email_format(changeset) do
    case get_field(changeset, :alarm_notification_email) do
      nil -> changeset
      email ->
        if String.trim(email) == "" do
          changeset
        else
          validate_format(changeset, :alarm_notification_email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "must be a valid email address")
        end
    end
  end

  defp validate_phone_format(changeset) do
    case get_field(changeset, :alarm_notification_phone) do
      nil -> changeset
      phone ->
        if String.trim(phone) == "" do
          changeset
        else
          # Remove all non-digit characters and validate length
          clean_phone = String.replace(phone, ~r/[^\d]/, "")
          if String.length(clean_phone) >= 10 and String.length(clean_phone) <= 15 do
            changeset
          else
            add_error(changeset, :alarm_notification_phone, "must be a valid phone number (10-15 digits), got: #{clean_phone} (#{String.length(clean_phone)} digits)")

          end
        end
    end
  end

  def update_sensor_input_selected(device_id, sensor_id, input_selected) do
    query = from s in "sensors",
      where: s.device_id == ^device_id and s.id == ^sensor_id

    case Repo.update_all(query, set: [input_selected: input_selected]) do
      {1, nil} -> {:ok, true}
      {0, nil} -> {:error, :not_found}
      _ -> {:error, :update_failed}
    end
  end
end

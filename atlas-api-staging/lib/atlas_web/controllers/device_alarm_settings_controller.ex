defmodule AtlasWeb.DeviceAlarmSettingsController do
  use AtlasWeb, :controller
  alias Atlas.{Devices, Organizations, SmsNotifier}
  require Logger

  def update(conn, %{"id" => device_id} = params) do
    device = Devices.get_device!(device_id)

    # Check if user has permission to update this device
    current_user = conn.assigns.current_user
    IO.inspect("alarm setting")

    if can_modify_device?(current_user, device) do
      # Handle phone number verification if provided
      alarm_settings = handle_phone_number_verification(params, device)

      case Devices.update_device(device, alarm_settings) do
        {:ok, updated_device} ->
          conn
          |> put_status(:ok)
          |> json(%{
            status: "success",
            message: "Device alarm settings updated successfully",
            device: %{
              id: updated_device.id,
              name: updated_device.name,
              alarm_email_enabled: updated_device.alarm_email_enabled,
              alarm_push_enabled: updated_device.alarm_push_enabled,
              alarm_sms_enabled: updated_device.alarm_sms_enabled,
              alarm_notification_email: updated_device.alarm_notification_email,
              alarm_notification_phone: updated_device.alarm_notification_phone
            }
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            status: "error",
            message: "Failed to update device alarm settings",
            errors: format_changeset_errors(changeset)
          })
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{
        status: "error",
        message: "You don't have permission to update this device's alarm settings"
      })
    end
  end

  def show(conn, %{"id" => device_id}) do
    device = Devices.get_device!(device_id)
    current_user = conn.assigns.current_user

    if can_modify_device?(current_user, device) do
      conn
      |> put_status(:ok)
      |> json(%{
        status: "success",
        device: %{
          id: device.id,
          name: device.name,
          alarm_email_enabled: device.alarm_email_enabled,
          alarm_push_enabled: device.alarm_push_enabled,
          alarm_sms_enabled: device.alarm_sms_enabled,
          alarm_notification_email: device.alarm_notification_email,
          alarm_notification_phone: device.alarm_notification_phone
        }
      })
    else
      conn
      |> put_status(:forbidden)
      |> json(%{
        status: "error",
        message: "You don't have permission to view this device's alarm settings"
      })
    end
  end

  @doc """
  Handles phone number verification when updating device alarm settings.
  If a phone number is provided and SMS is enabled, it will be added to Twilio's verified caller list.
  """
  defp handle_phone_number_verification(params, device) do
    phone_number = params["alarm_notification_phone"]

    # Check if phone number is provided and SMS is enabled
    if phone_number && phone_number != "" do
      IO.inspect("Phone number provided in request:Adding to Twilio verified caller list.")

      # Create friendly name for the device
      friendly_name = "Atlas Device: #{device.name || device.serial_number}"

      # Add phone number to Twilio verified caller list
      %{
        alarm_email_enabled: params["alarm_email_enabled"],
        alarm_push_enabled: params["alarm_push_enabled"],
        alarm_sms_enabled: params["alarm_sms_enabled"],
        alarm_notification_email: params["alarm_notification_email"],
        alarm_notification_phone: params["alarm_notification_phone"]
      }
    else
      # No phone number provided or SMS not enabled, return settings as is
      %{
        alarm_email_enabled: params["alarm_email_enabled"],
        alarm_push_enabled: params["alarm_push_enabled"],
        alarm_sms_enabled: params["alarm_sms_enabled"],
        alarm_notification_email: params["alarm_notification_email"],
        alarm_notification_phone: params["alarm_notification_phone"]
      }
    end
  end

  @doc """
  Checks if a phone number is already verified in Twilio's verified caller list.
  """
  def check_phone_verification_status(conn, %{"phone_number" => phone_number}) do
    case SmsNotifier.check_verification_status(phone_number) do
      {:ok, %{status: status, friendly_name: name, sid: sid}} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "success",
          phone_number: phone_number,
          verification_status: status,
          friendly_name: name,
          verification_sid: sid
        })

      {:not_found} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "not_found",
          phone_number: phone_number,
          message: "Phone number is not in Twilio's verified caller list"
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          status: "error",
          phone_number: phone_number,
          message: "Failed to check verification status",
          error: reason
        })
    end
  end

  @doc """
  Manually adds a phone number to Twilio's verified caller list.
  """
  def add_phone_to_verified_list(conn, %{"phone_number" => phone_number, "device_id" => device_id}) do
    device = Devices.get_device!(device_id)
    current_user = conn.assigns.current_user

    if can_modify_device?(current_user, device) do
      friendly_name = "Atlas Device: #{device.name || device.serial_number}"

      case SmsNotifier.add_to_verified_caller_list(phone_number, friendly_name) do
        {:ok, verification_sid} ->
          Logger.info("Manually added phone number #{phone_number} to Twilio verified caller list. SID: #{verification_sid}")

          conn
          |> put_status(:ok)
          |> json(%{
            status: "success",
            message: "Phone number added to Twilio verified caller list",
            phone_number: phone_number,
            verification_sid: verification_sid,
            device_id: device_id
          })

        {:error, reason} ->
          Logger.error("Failed to manually add phone number #{phone_number} to Twilio verified caller list: #{reason}")

          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            status: "error",
            message: "Failed to add phone number to Twilio verified caller list",
            phone_number: phone_number,
            error: reason
          })
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{
        status: "error",
        message: "You don't have permission to modify this device"
      })
    end
  end

  defp can_modify_device?(current_user, device) do
    # Super admin can modify any device
    user_org = Atlas.Accounts.get_user_organization(current_user.id, device.organization_id)

    case user_org do
      nil -> false
      user_org ->
        case user_org.role.role do
          "super_admin" -> true
          "admin" -> true
          "user" -> device.user_id == current_user.id
          _ -> false
        end
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

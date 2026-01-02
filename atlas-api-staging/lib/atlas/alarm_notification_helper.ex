defmodule Atlas.AlarmNotificationHelper do
  @moduledoc """
  Helper module for handling alarm notifications with preference checking.
  Implements the hierarchy: Device settings > User settings > Organization settings
  """

  require Logger
  alias Atlas.{Devices, Accounts, Organizations, MobileNotifier, SmsNotifier}
  import Bamboo.Email

  def check_and_send_alarm_notifications(device, data) do
    case data do
      1 ->
        # Get device with organization preloaded
        device_with_associations = Devices.get_device!(device.id)
          |> Atlas.Repo.preload([:organization])

        # Get organization settings
        organization = device_with_associations.organization

        # Determine notification preferences based on hierarchy
        preferences = determine_notification_preferences(device_with_associations, organization)

        # Send notifications asynchronously if enabled
        Task.start(fn ->
          # Check if device has email for notifications

          if device_with_associations.alarm_notification_email && preferences.email_enabled do
            send_alarm_email_notification(device_with_associations, preferences)
          end

          if preferences.push_enabled do
            send_alarm_sms_notification(device_with_associations, preferences)
          end
        end)
      _ ->
        :ok
    end
  end

  defp determine_notification_preferences(device, organization) do
    # Get organization location preference
    org_location_preference = organization.general_alarm_location_preference

    # If organization location preference is false, check device alarm settings
    if org_location_preference == true do
      # Use device alarm settings for email and push notifications
      device_email_enabled = device.alarm_email_enabled
      device_push_enabled = device.alarm_push_enabled
      device_sms_enabled = device.alarm_sms_enabled

      %{
        email_enabled: device_email_enabled,
        push_enabled: device_push_enabled,
        sms_enabled: device_sms_enabled,
        location_preference: true  # Always false when org preference is false
      }
    else
      # Otherwise, check device settings (original logic)
      org_location_preference = organization.general_alarm_location_preference

      org_email_enabled = organization.general_alarm_email_enabled
      org_push_enabled = organization.general_alarm_push_enabled
      org_sms_enabled = organization.general_alarm_sms_enabled

      %{
        email_enabled: org_email_enabled,
        push_enabled: org_push_enabled,
        sms_enabled: org_sms_enabled,
        location_preference: org_location_preference
      }
    end
  end

  defp send_alarm_email_notification(device, preferences) do
    try do
      device_name = device.name || "Device #{device.serial_number}"

      # Include location information if preference is enabled
      location_info = if preferences.location_preference do
        """
        <li>Location: #{device.latitude}, #{device.longitude}</li>
        """
      else
        ""
      end

      email_content = """
      <h2>🚨 Device Alarm Alert</h2>
      <p>Hello,</p>
      <p>Your device <strong>#{device_name}</strong> has triggered an alarm.</p>
      <p><strong>Device Details:</strong></p>
      <ul>
        <li>Device Name: #{device_name}</li>
        <li>Serial Number: #{device.serial_number}</li>
        #{location_info}
        <li>Time: #{format_datetime(device.updated_at)}</li>
      </ul>
      <p>Please check your device immediately.</p>
      <p>Best regards,<br>Atlas Sensor Dashboard</p>
      """

      text_content = """
      Device Alarm Alert

      Hello,

      Your device #{device_name} has triggered an alarm.

      Device Details:
      - Device Name: #{device_name}
      - Serial Number: #{device.serial_number}
      #{if preferences.location_preference, do: "- Location: #{device.latitude}, #{device.longitude}", else: ""}
      - Time: #{format_datetime(device.updated_at)}

      Please check your device immediately.

      Best regards,
      Atlas Sensor Dashboard
      """

      email = new_email()
      |> to(device.alarm_notification_email)
      |> from({"Atlas Sensor Dashboard", "atlas.sensor1@gmail.com"})
      |> subject("🚨 Device Alarm Alert - #{device_name}")
      |> html_body(email_content)
      |> text_body(text_content)

      Atlas.Mailer.deliver_now(email) |> IO.inspect()

      Logger.info("Alarm email notification sent to #{device.alarm_notification_email} for device #{device.id}")
    rescue
      error ->
        Logger.error("Failed to send alarm email notification: #{inspect(error)}")
    end
  end

  defp send_alarm_push_notification(user, device, preferences) do
    try do
      device_name = device.name || "Device #{device.serial_number}"

      # Include location information if preference is enabled
      location_data = if preferences.location_preference do
        %{
          device_id: device.id,
          device_name: device_name,
          alarm_time: format_datetime(device.updated_at),
          latitude: device.latitude,
          longitude: device.longitude
        }
      else
        %{
          device_id: device.id,
          device_name: device_name,
          alarm_time: format_datetime(device.updated_at)
        }
      end

      Atlas.MobileNotifier.send_push_notification(
        Integer.to_string(user.id),
        "🚨 Device Alarm",
        "Device #{device_name} has triggered an alarm",
        "Check your device immediately",
        location_data,
        nil
      )

      Logger.info("Alarm push notification sent to user #{user.id} for device #{device.id}")
    rescue
      error ->
        Logger.error("Failed to send alarm push notification: #{inspect(error)}")
    end
  end

  defp send_alarm_sms_notification(device, preferences) do
    try do
      device_name = device.name || "Device #{device.serial_number}"


      # Create the SMS message
      location_info = if preferences.location_preference and device.latitude and device.longitude do
        " at location #{device.latitude}, #{device.longitude}"
      else
        ""
      end

      message = "Device #{device_name} has triggered an alarm#{location_info}. Please check immediately."

      # Send the SMS
      case SmsNotifier.send_sms_notification(device.alarm_notification_phone, message, device_name) do
        {:ok, _response} ->
          Logger.info("Alarm SMS notification sent to #{device.alarm_notification_phone} for device #{device.id}")

        {:error, reason} ->
          Logger.error("Failed to send alarm SMS notification: #{reason}")
      end
    rescue
      error ->
        Logger.error("Failed to send alarm SMS notification: #{inspect(error)}")
    end
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.to_string()
    |> String.replace(~r/T/, " ")
    |> String.replace(~r/\.\d+Z$/, "Z")
    |> (&("U[" <> &1 <> "]")).()
  end
end

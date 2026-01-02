defmodule AtlasWeb.DomController do
  use AtlasWeb, :controller
  alias Atlas.{Devices, Cmd, Accounts, AlarmNotificationHelper}
  require Logger
  import Bamboo.Email

  def create(conn, params) do
    Logger.info("API hit: Device data: #{inspect(params)}")
    commands = case Devices.get_device_by_serial_number(params["gateway_slug"]) do
      nil -> []
      device ->
        case Cmd.get_commands_by_device(device.id) do
          {:ok, cmds} -> cmds
          _ -> []
        end
    end
    with {:ok, _device_data} <- validate_device_data(params),
         {:ok, device} <- get_or_create_device(params["gateway_slug"], params["data"] |> List.first()),
         {:ok, _sensor_data} <- process_sensor_data(device, params["data"])
         do
          update_device_timestamp(device)

          # Check for alarm and send notifications
          AlarmNotificationHelper.check_and_send_alarm_notifications(device, params["data"] |> List.first() |> Map.get("ALARM"))

          json(conn, %{status: "success", command_details: commands})
    else
      {:error, :invalid_device_data} ->
        Logger.info("response: invalid_device_data")
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid device data format", command_details: commands})

      {:error, :no_device} ->
        Logger.info("response: no_device")
        conn
        |> put_status(:not_found)
        |> json(%{error: "No location assigned to device", command_details: commands})

      {:error, failed_operation, failed_value, _changes_so_far} ->
        error_details = format_changeset_errors(failed_value)
        Logger.error("Sensor data processing failed at #{inspect(failed_operation)}: #{inspect(error_details)}")
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Failed to process sensor data",
          operation: failed_operation,
          details: error_details,
          command_details: commands
        })

      {:error, reason} ->
        Logger.info("response: internal_server_error")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error", details: inspect(reason), command_details: commands})
    end
  end

  defp update_device_timestamp(device) do
    current_time = DateTime.utc_now() |> DateTime.truncate(:second)
    formatted_time = format_datetime(current_time)

    case Devices.update_device(device, %{updated_at: current_time, status: "online"}) do
      {:ok, _device} ->
        IO.puts("Device updated at: #{formatted_time}")
      {:error, reason} ->
        IO.puts("Failed to update device: #{reason}")
    end
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.to_string()
    |> String.replace(~r/T/, " ")
    |> String.replace(~r/\.\d+Z$/, "Z")
    |> (&("U[" <> &1 <> "]")).()
  end




  defp get_or_create_device(gateway_slug, params) do
    Logger.info("get_or_create_device: #{inspect(gateway_slug)}")
    Logger.info("get_or_create_device: #{inspect(params)}")
    case Devices.get_device_by_serial_number(gateway_slug) do
      nil -> {:error, :no_device}
      device ->
        with data when not is_nil(data) <- params do
          # Extract optional fields if they exist
          optional_fields = %{
            "tb" => Map.get(data, "TB1"),
            "sl" => Map.get(data, "SL1"),
            "pb" => Map.get(data, "PB1"),
            "tr" => Map.get(data, "TR1"),
            "rl" => Map.get(data, "RL1"),
            "ph" => Map.get(data, "PH1"),
            "alarm" => Map.get(data, "ALARM"),
            "wn" => Map.get(data, "wn_network"),
            "firmware_version" => Map.get(data, "firm_ver"),
            "name" => Map.get(data, "name") || Map.get(data, "nickname"),
            "mac_address" => Map.get(data, "mac_address") || Map.get(data, "mac"),
            "auto_region" => Map.get(data, "auto_gen") || Map.get(data, "auto_region") || Map.get(data, "auto_regen"),
            "alarm_notification_phone" => Map.get(data, "cell_number")
          }

          IO.inspect(optional_fields, label: "optional_fields")
          # Filter out nil values
          optional_fields = Map.filter(optional_fields, fn {_k, v} -> v != nil end)

          # Merge with required fields
          update_params = Map.merge(%{
            "latitude" => data["latitude"],
            "longitude" => data["longitude"],
            "model_id" => data["model"],
            "updated_at" => DateTime.utc_now(),
            "status" => "online",
          }, optional_fields)
          case Devices.update_device(device, update_params) do
            {:ok, updated_device} ->
              {:ok, Atlas.Repo.preload(updated_device, sensors: [:sensor_data])}
            error -> error
          end
        else
          _ -> {:error, :invalid_device_data}
        end
    end
  end

  defp process_sensor_data(device, sensor_data) do
    # List of fields that should be treated as device fields, not sensor data
    device_fields = [
      # Location fields
      "latitude", "longitude",
      # 3-character fields
      "tb", "sl", "pb", "tr", "rl", "ph",
      # Status fields
      "alarm",
      # Network fields
      "wn", "wn_network",
      # Version fields
      "firmware_version",
      # Device identification fields
      "nickname", "mac", "auto_regen"
    ]

    Enum.reduce(sensor_data, Ecto.Multi.new(), fn data, multi ->
      # Remove device-specific fields from sensor data
      data = data |> Map.drop(device_fields)

      Enum.reduce(data, multi, fn {key, value}, multi ->
        Logger.info("Processing sensor #{key} with value: #{inspect(value)}")
        # Convert value to decimal if possible
        converted_value = case value do
          nil -> nil
          value when is_binary(value) ->
            case Decimal.parse(value) do
              {decimal, _} -> decimal
              :error -> nil
            end
          value when is_number(value) -> Decimal.new(value)
          _ -> nil
        end

        case Devices.get_sensor_by_channel(device.id, key) do
          nil ->
            multi
            |> Ecto.Multi.insert(
              "sensor_#{key}",
              %Devices.Sensor{}
              |> Devices.Sensor.changeset(%{
                device_id: device.id,
                channel: key,
                name: key,
                updated_at: DateTime.utc_now()
              })
            )
            |> Ecto.Multi.insert("sensor_data_#{key}", fn %{("sensor_" <> ^key) => sensor} ->
              %Devices.SensorDatum{}
              |> Devices.SensorDatum.changeset(%{
                sensor_id: sensor.id,
                value: converted_value,
                epoch: System.system_time(:second),
                updated_at: DateTime.utc_now()
              })
            end)

          sensor ->
            multi
            |> Ecto.Multi.insert(
              "sensor_data_#{key}",
              %Devices.SensorDatum{}
              |> Devices.SensorDatum.changeset(%{
                sensor_id: sensor.id,
                value: converted_value,
                epoch: System.system_time(:second),
                updated_at: DateTime.utc_now()
              })
            )
        end
      end)
    end)
    |> Atlas.Repo.transaction()
  end

  defp validate_device_data(%{"model" => model, "version" => version, "data" => data})
       when is_list(data) and length(data) > 0 do
    {:ok, %{model: model, version: version, data: data}}
  end

  defp validate_device_data(_), do: {:error, :invalid_device_data}

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

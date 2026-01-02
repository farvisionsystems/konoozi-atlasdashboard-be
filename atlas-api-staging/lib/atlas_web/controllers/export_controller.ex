defmodule AtlasWeb.ExportController do
  use AtlasWeb, :controller
  alias Atlas.{Devices, Repo}
  import Ecto.Query, warn: false
  require Logger

  @doc """
  Exports sensor data based on specified parameters.

  ## Parameters
    - devices: List of device IDs to export data from
    - sensors: List of sensor configurations with device_id, sensor_id, and channel
    - start_date: Start date in ISO format
    - end_date: End date in ISO format
    - timezone: Timezone for date conversion (default: "America/New_York")
    - format: Export format ("csv", "json", "excel") - default: "csv"

  ## Returns
    - CSV/JSON/Excel file with exported data
  """
  def export_data(%{assigns: %{current_user: current_user}} = conn, params) do
    with {:ok, export_config} <- validate_export_params(params),
         {:ok, sensors} <- get_sensors_for_export(export_config.sensors, current_user.organization_id),
         {:ok, data} <- collect_export_data(sensors, export_config),
         {:ok, formatted_data} <- format_export_data(data, export_config) do

      case export_config.format do
        "csv" ->
          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", "attachment; filename=\"sensor_data_#{Date.utc_today()}.csv\"")
          |> send_resp(200, formatted_data)

        "json" ->
          conn
          |> put_resp_content_type("application/json")
          |> put_resp_header("content-disposition", "attachment; filename=\"sensor_data_#{Date.utc_today()}.json\"")
          |> json(%{
            status: "success",
            export_config: export_config,
            data: formatted_data
          })

        _ ->
          conn
          |> put_status(:bad_request)
          |> json(%{status: "error", message: "Unsupported export format"})
      end
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: "Export failed: #{inspect(reason)}"})
    end
  end

  @doc """
  Gets available devices and sensors for export configuration.

  ## Returns
    - List of devices with their sensors for export selection
  """
  def get_export_config(%{assigns: %{current_user: current_user}} = conn, _params) do
    user_org = hd(current_user.user_organizations)
    role = user_org.role.role

    devices = Devices.get_devices(current_user.organization_id, role, current_user.id)

    export_config = Enum.map(devices, fn device ->
      sensors = Enum.map(device.sensors, fn sensor ->
        %{
          sensor_id: sensor.id,
          name: sensor.name,
          channel: sensor.channel,
          metric: get_sensor_metric_type(sensor),
          value: get_latest_sensor_value(sensor.id)
        }
      end)

      %{
        device_id: device.id,
        device_name: device.name,
        sensors: sensors
      }
    end)

    conn
    |> put_status(:ok)
    |> json(%{
      status: "success",
      data: export_config
    })
  end

  defp validate_export_params(params) do
    required_fields = ["sensors", "start_date", "end_date"]

    case Enum.all?(required_fields, &Map.has_key?(params, &1)) do
      true ->
        {:ok, %{
          sensors: params["sensors"],
          start_date: params["start_date"],
          end_date: params["end_date"],
          timezone: Map.get(params, "timezone", "America/New_York"),
          format: Map.get(params, "format", "csv")
        }}
      false ->
        {:error, "Missing required fields: #{Enum.join(required_fields, ", ")}"}
    end
  end

  defp get_sensors_for_export(sensor_configs, organization_id) do
    sensor_ids = Enum.map(sensor_configs, & &1["sensor_id"])


    query = from s in Atlas.Devices.Sensor,
      join: d in Atlas.Devices.Device, on: s.device_id == d.id,
      where: s.id in ^sensor_ids and d.organization_id == ^organization_id and is_nil(d.deleted_at),
      select: %{
        sensor_id: s.id,
        device_id: d.id,
        device_name: d.name,
        sensor_name: s.name,
        channel: s.channel,
        sensor_type_uid: s.sensor_type_uid
      }

    sensors = Repo.all(query)

    if length(sensors) == length(sensor_ids) do
      {:ok, sensors}
    else
      {:error, "Some sensors not found or not accessible"}
    end
  end

  defp collect_export_data(sensors, config) do
    start_epoch = parse_datetime_to_epoch(config.start_date, config.timezone)
    end_epoch = parse_datetime_to_epoch(config.end_date, config.timezone)

    data = Enum.map(sensors, fn sensor ->
      case Devices.get_historical_data(
        %{sensor: %{id: sensor.sensor_id, sensor_type_uid: sensor.sensor_type_uid}},
        start_epoch,
        end_epoch,
        1,  # Get all data points
        "english"
      ) do
        {:ok, readings} ->
          {sensor, readings}
        {:error, reason} ->
          Logger.error("Failed to get data for sensor #{sensor.sensor_id}: #{reason}")
          {sensor, []}
      end
    end)

    {:ok, data}
  end

  defp format_export_data(data, config) do
    case config.format do
      "csv" -> format_csv_data(data, config)
      "json" -> format_json_data(data, config)
      _ -> {:error, "Unsupported format"}
    end
  end

  defp format_csv_data(data, config) do
    # Create CSV header
    header = ["Date"] ++
             Enum.map(data, fn {sensor, _} ->
               "#{sensor.device_name}:#{sensor.sensor_name}"
             end)

    # Collect all unique timestamps
    all_timestamps = data
    |> Enum.flat_map(fn {_, readings} ->
      Enum.map(readings, fn [timestamp, _, _] -> timestamp end)
    end)
    |> Enum.uniq()
    |> Enum.sort()

    # Create data rows
    rows = Enum.map(all_timestamps, fn timestamp ->
      date_str = format_timestamp(timestamp, config.timezone)
      [date_str] ++
      Enum.map(data, fn {_, readings} ->
        case Enum.find(readings, fn [ts, _, _] -> ts == timestamp end) do
          [_, value, _] -> format_value(value)
          nil -> ""
        end
      end)
    end)

    csv_content = [header] ++ rows
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")

    {:ok, csv_content}
  end

  defp format_json_data(data, config) do
    json_data = %{
      export_config: %{
        start_date: config.start_date,
        end_date: config.end_date,
        timezone: config.timezone,
        location: "Watts Water"  # This could be made configurable
      },
      data: Enum.map(data, fn {sensor, readings} ->
        %{
          device: sensor.device_name,
          sensor: sensor.sensor_name,
          channel: sensor.channel,
          readings: Enum.map(readings, fn [timestamp, value, alarm] ->
            %{
              date: format_timestamp(timestamp, config.timezone),
              value: format_value(value),
              alarm: alarm
            }
          end)
        }
      end)
    }

    {:ok, json_data}
  end

  defp parse_datetime_to_epoch(datetime_str, timezone) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _} ->
        # Convert to the specified timezone first, then to UTC epoch
        datetime
        |> DateTime.shift_zone!(timezone)
        |> DateTime.to_unix()
      _ ->
        # Try parsing as local datetime in the specified timezone
        case NaiveDateTime.from_iso8601(datetime_str) do
          {:ok, naive_datetime} ->
            # Convert to the specified timezone, then to UTC epoch
            naive_datetime
            |> DateTime.from_naive!(timezone)
            |> DateTime.to_unix()
          _ ->
            Logger.error("Failed to parse datetime: #{datetime_str}")
            0
        end
    end
  end

  defp format_timestamp(timestamp_ms, timezone) do
    timestamp_ms
    |> div(1000)  # Convert from milliseconds to seconds
    |> DateTime.from_unix!()
    |> DateTime.shift_zone!(timezone)
    |> Calendar.strftime("%m/%d/%Y %H:%M")
  end

  defp format_value(value) when is_number(value) do
    if is_integer(value) do
      to_string(value)
    else
      :erlang.float_to_binary(value, [decimals: 2])
    end
  end
  defp format_value(nil), do: ""
  defp format_value(value), do: to_string(value)

  defp get_sensor_metric_type(sensor) do
    case sensor.sensor_type_uid do
      1 -> "Temperature"
      2 -> "Humidity"
      3 -> "Pressure"
      4 -> "Flow"
      _ -> "Value"
    end
  end

  defp get_latest_sensor_value(sensor_id) do
    case Devices.get_sensor_data(sensor_id, 1, :desc) do
      [latest | _] -> format_value(latest.value)
      [] -> "0.00"
    end
  end
end

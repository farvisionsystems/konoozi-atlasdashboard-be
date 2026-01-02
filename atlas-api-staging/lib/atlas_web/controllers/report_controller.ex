defmodule AtlasWeb.ReportController do
  use AtlasWeb, :controller


  alias Atlas.Reports
  alias Atlas.ReportTemplates
  alias Atlas.Accounts


  def create(conn, params) do
    with {:ok, display_name} <- validate_display_name(params["value"]),
         slug <- generate_unique_slug(),
         attrs = %{
           slug: slug,
           display_name: display_name,
           organization_id: conn.assigns.current_user.organization_id,
           created_by_id: conn.assigns.current_user.id
         },
         {:ok, report} <- Reports.create(attrs) do
      conn
      |> json(%{
        status: "success",
        message: "Report Created.",
        data: %{
          report_id: report.id,
          slug: slug
        }
      })
    else
      {:error, :invalid_display_name} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Display name is required"})

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Could not create report", errors: errors})
    end
  end

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    role = Accounts.get_user_role(current_user.id, current_user.organization_id)
    user_id_param =
      case role && Map.get(role, :role) do
        "super_admin" -> nil
        "admin" -> nil
        _ -> current_user.id
      end

    reports = Reports.list_by_organization(current_user.organization_id, user_id_param)
    json(conn, %{
      status: "success",
      data: reports
    })
  end

  def set_sensors(conn, params) do
    case params do
      %{"report_id" => report_id, "sensors" => sensors} when is_list(sensors) ->
        with {:ok, report} <- Reports.get_report(report_id),
             {:ok, _} <- Reports.set_sensors(report, sensors) do
          conn
          |> json(%{
            status: "success",
            message: "Sensors updated successfully"
          })
        else
          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{status: "error", message: "Report not found"})

          {:error, :invalid_sensors} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{status: "error", message: "Invalid sensors data"})

          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{status: "error", message: "Failed to update sensors"})
        end

      %{"report_id" => _report_id, "sensors" => _sensors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: "Sensors must be a list"})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: "Missing required parameters: report_id and sensors"})
    end
  end

  def show(conn, %{"id" => id}) do
    case Reports.get_detail_json(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Report not found"})

      report ->
        json(conn, report)
    end
  end

  def update(conn, %{"id" => id} = params) do
    permitted_params = [
      :display_name,
      :sample_interval,
      :run_interval,
      :run_now_duration,
      :agg_function,
      :last_run_epoch,
      :distribution,
      :active_status
    ]

    update_params = params
      |> Map.take(Enum.map(permitted_params, &(to_string(&1))))
      |> AtlasWeb.Utils.atomize_keys()

    with {:ok, report} <- Reports.get_report(id),
         {:ok, updated_report} <- Reports.update(report, update_params) do
      json(conn, %{
        status: "success",
        message: "Report updated successfully",
        data: updated_report
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Report not found"})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Could not update report", errors: errors})
    end
  end

  def save_distribution(conn, params) do
      with distribution = params["distribution"],
         user_uids = params["distribution_user_uids"],
         manual_emails = params["manual_email_distributions"],
         report_id = params["report_id"],
         {:ok, _updated} <- Reports.save_distribution(report_id, distribution, user_uids, manual_emails) do
      json(conn, %{
        status: "success",
        message: "Report Saved."
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{status: "error", message: "You do not have permission to edit this content"})

      {:error, :invalid_report} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Report not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: reason})
    end
  end

  @spec run_report(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def run_report(conn, %{"report_uid" => report_uid} = params) do
    IO.inspect(params)
    # Get date from params, default to current date if not provided
    month_day_year = Map.get(params, "date") || get_current_date_string()
    IO.inspect(month_day_year)

    opts = params
           |> Map.take(["force_interval", "manual_run", "is_arbitrary_duration"])
           |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
           |> Enum.into(%{})


    with {:ok, report} <- get_report(report_uid),
         {:ok, report} <- maybe_force_interval(report, opts[:force_interval]),
         {:ok, template} <- get_template(report),
         {:ok, sensors} <- get_sensors(report_uid) do

      case process_report(report, template, sensors, month_day_year, opts) do
        :ok ->
          json(conn, %{
            status: "success",
            message: "Report generated successfully"
          })
        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{status: "error", message: "Failed to generate report: #{inspect(reason)}"})
      end
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Failed to run report: #{inspect(reason)}"})
    end
  end

  defp process_report(report, template, sensors, month_day_year, opts) do
    with {:ok, date_info} <- parse_date(month_day_year),
         {:ok, run_config} <- calculate_run_config(report, date_info),
         {:ok, report_data} <- collect_sensor_data(sensors, run_config, report),
         {:ok, stored_data} <- Reports.store_report_data(
          report.id,
          report_data,
          if(to_string(report.sample_interval) == "", do: "hour_24", else: to_string(report.sample_interval)),
          if(to_string(report.agg_function) == "", do: "avg", else: to_string(report.agg_function)),
          date_info
        ),
         :ok <- Reports.update_last_run(report) do
      :ok
    else
      {:error, reason} -> {:error, "Failed to generate report: #{inspect(reason)}"}
    end
  end

  defp get_report(report_uid) do
    case Reports.get_report(report_uid) do
      {:ok, report} -> {:ok, report}
      {:error, :not_found} -> {:error, :report_not_found}
    end
  end

  defp maybe_force_interval(report, nil), do: {:ok, report}
  defp maybe_force_interval(report, interval), do: {:ok, %{report | run_interval: interval}}

  defp get_template(_report) do
    # TODO: Implement proper template retrieval when ReportTemplates module is available
    # For now, return default template
    {:ok, %{
      report_template_uid: 1,
      slug: "default-template",
      display_name: "Default Template",
      model_name: "default",
      is_delete: 0
    }}
  end

  defp get_sensors(report_id) do
    case Reports.get_sensors(report_id) do
      {:ok, sensors} -> {:ok, sensors}
      {:error, reason} -> {:error, reason}
    end
  end

  defp calculate_run_config(report, {month, day, year}) do
    run_days = case report.run_interval do
      30 -> :calendar.last_day_of_the_month(year, month)
      7 -> 7
      n when is_integer(n) and n > 0 -> n
      _ -> 1
    end

    start_epoch = case report.run_interval do
      30 -> DateTime.new!(Date.new!(year, month, 1), ~T[00:00:00])
      _ -> DateTime.new!(Date.new!(year, month, day), ~T[00:00:00])
    end |> DateTime.to_unix()
    IO.inspect(start_epoch, label: "start_epoch")
    IO.inspect(run_days, label: "run_days")
    IO.inspect(year, label: "year")
    IO.inspect(month, label: "month")
    IO.inspect(day, label: "day")

    {:ok, %{run_days: run_days, start_epoch: start_epoch}}
  end

  defp collect_sensor_data(sensors, run_config, report) do
    sample_interval = convert_sample_interval(report.sample_interval)

    sensor_data =
      for run_day <- 0..(run_config.run_days - 1),
          hour <- 0..23,
          hour == 0 or rem(hour, sample_interval) == 0 do

        epoch_hour = run_config.start_epoch + (run_day * 24 * 60 * 60) + (hour * 60 * 60)
        stop_epoch = epoch_hour + (sample_interval * 60 * 60) - 1
        sensor_readings = collect_sensor_readings(sensors, epoch_hour, stop_epoch, report)

        {run_day, hour, %{
          epoch: epoch_hour,
          data: sensor_readings
        }}
      end

    {:ok, Reports.format_sensor_data(sensor_data)}
  end

  defp convert_sample_interval(interval) do
    case interval do
      :hour_1 -> 1
      :hour_2 -> 2
      :hour_4 -> 4
      :hour_6 -> 6
      :hour_12 -> 12
      :hour_24 -> 24
      _ -> 24  # default to 24 hours if invalid/nil
    end
  end

  defp collect_sensor_readings(sensors, start_epoch, stop_epoch, report) do
    sensors
    |> Enum.map(fn sensor ->
      readings = Atlas.Devices.get_historical_data(
        sensor,
        start_epoch,
        stop_epoch,
        Reports.calculate_sample_count(report),
        "english"
      )
      process_sensor_readings(sensor, readings)
    end)
    |> Map.new()
  end

  defp process_sensor_readings(sensor, readings) do
    case readings do
      {:ok, []} ->
        {sensor.sensor.name, %{first: nil, min: nil, max: nil, ave: nil, is_alarm: 0}}
      {:ok, [first | _] = readings_list} ->
        [_timestamp, initial_value | _] = first
        stats = Enum.reduce(readings_list, %{min: initial_value, max: initial_value, sum: 0, alarm: 0}, fn
          [_, value, alarm], acc when is_number(value) ->
            %{
              min: min(acc.min, value),
              max: max(acc.max, value),
              sum: acc.sum + value,
              alarm: max(acc.alarm, alarm || 0)
            }
        end)

        {sensor.sensor.name, %{
          first: initial_value,
          min: stats.min,
          max: stats.max,
          ave: stats.sum / length(readings_list),
          is_alarm: stats.alarm
        }}
      {:error, _} ->
        {sensor.sensor.name, %{first: nil, min: nil, max: nil, ave: nil, is_alarm: 0}}
      _ ->
        {sensor.sensor.name, %{first: nil, min: nil, max: nil, ave: nil, is_alarm: 0}}
    end
  end

  defp save_report_files(path, filename, html) do
    full_path = Path.join(path, filename)

    with :ok <- File.write("#{full_path}.html", html),
         {:ok, pdf} <- generate_pdf(html),
         :ok <- File.write("#{full_path}.pdf", pdf) do
      :ok
    end
  end

  defp generate_pdf(html) do
    {:ok, pdf} = PdfGenerator.generate(html, page_size: :a4, orientation: :portrait)
    {:ok, pdf}
  end

  defp validate_report_slug(slug) when is_binary(slug) do
    case Reports.get_by_slug(slug) do
      nil -> {:error, :invalid_report}
      report -> {:ok, report}
    end
  end

  defp validate_report_slug(_), do: {:error, :invalid_report}

  defp authorize_edit(report, user) do
    case Reports.check_permissions(report, user) do
      %{edit: permission} when permission > 0 -> :ok
      _ -> {:error, :unauthorized}
    end
  end

  # Helper function to generate unique slugs
  defp generate_unique_slug do
    slug = generate_random_string(8)
    case Reports.get_by_slug(slug) do
      nil -> slug
      _report -> generate_unique_slug()
    end
  end

  defp generate_random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
    |> String.downcase()
  end

  defp validate_display_name(nil), do: {:error, :invalid_display_name}
  defp validate_display_name(""), do: {:error, :invalid_display_name}
  defp validate_display_name(display_name) when is_binary(display_name), do: {:ok, display_name}
  defp validate_display_name(_), do: {:error, :invalid_display_name}

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp get_current_date_string do
    today = Date.utc_today()
    "#{today.month}/#{today.day}/#{today.year}"
  end

  defp parse_date(month_day_year) when is_binary(month_day_year) do
    # Support both "/" and "-" separators
    separator = if String.contains?(month_day_year, "/"), do: "/", else: "-"
    case String.split(month_day_year, separator) do
      [month, day, year] ->
        with {month, _} <- Integer.parse(month),
             {day, _} <- Integer.parse(day),
             {year, _} <- Integer.parse(year),
             true <- month in 1..12,
             true <- day in 1..31,
             true <- year >= 2000 do
          {:ok, {month, day, year}}
        else
          _ -> {:error, :invalid_date_format}
        end
      _ ->
        {:error, :invalid_date_format}
    end
  end
  defp parse_date(_), do: {:error, :invalid_date_format}

  def report_history(conn, %{"report_id" => report_id} = params) do
    # Get optional date filter from query params or body
    date_filter = Map.get(params, "date")

    with {:ok, report} <- Reports.get_report(report_id),
         report_data <- Reports.list_report_data_history(report_id, date_filter) do

      history_data = Enum.map(report_data, fn entry ->
        %{
          id: entry.id,
          report_id: entry.report_id,
          data: entry.data,
          sample_interval: entry.sample_interval,
          agg_function: entry.agg_function,
          generated_at: entry.generated_at,
          inserted_at: entry.inserted_at
        }
      end)

      json(conn, %{
        status: "success",
        data: %{
          report: %{
            id: report.id,
            display_name: report.display_name,
            slug: report.slug
          },
          history: history_data
        }
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Report not found"})

      error ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{status: "error", message: "Failed to fetch report history: #{inspect(error)}"})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, report} <- Reports.get_report(id),
         {:ok, _deleted} <- Reports.delete_report(report) do
      json(conn, %{
        status: "success",
        message: "Report deleted successfully"
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Report not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Failed to delete report: #{inspect(reason)}"})
    end
  end

  def delete_report_data(conn, %{"id" => id}) do
    with {:ok, report_data} <- Reports.get_report_data_by_id(id),
         {:ok, _deleted} <- Reports.delete_report_data(report_data) do
      json(conn, %{
        status: "success",
        message: "Report data deleted successfully"
      })
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "Report data not found"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: "Failed to delete report data: #{inspect(reason)}"})
    end
  end
end

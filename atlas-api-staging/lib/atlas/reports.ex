defmodule Atlas.Reports do
  alias Atlas.Repo
  alias Atlas.Reports.Report
  alias Atlas.Reports.ReportDistribution
  alias Atlas.Reports.ReportData
  import Ecto.Query
  alias Decimal

  def create(attrs \\ %{}) do
    %Report{}
    |> Report.changeset(attrs)
    |> Repo.insert()
  end

  def get_by_slug(slug) do
    Repo.get_by(Report, slug: slug)
  end

  def list_by_organization(organization_id, nil) do
    Report
    |> where([r], r.organization_id == ^organization_id)
    |> where([r], r.is_delete == false)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  def list_by_organization(organization_id, user_id) do
    Report
    |> where([r], r.organization_id == ^organization_id)
    |> where([r], r.created_by_id == ^user_id)
    |> where([r], r.is_delete == false)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  def set_sensors(report, sensors) when is_list(sensors) do
    # Delete existing sensors first
    Repo.delete_all(from(rs in Atlas.Reports.ReportSensor, where: rs.report_uid == ^report.id))

    # Insert new sensors
    sensors
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {sensor_id, index}, multi ->
      Ecto.Multi.insert(multi,
        {:sensor, index},
        %Atlas.Reports.ReportSensor{
          report_uid: report.id,
          sensor_uid: sensor_id,
          display_order: index
        }
      )
    end)
    |> Repo.transaction()
  end

  def set_sensors(_, _), do: {:error, :invalid_sensors}

  def get_report(id) do
    case Repo.get(Report, id) do
      nil ->
        {:error, :not_found}
      report ->
        {:ok, report}
    end
  end

  def get_detail(id) do
    Report
    |> preload([:organization, :created_by, :reports_distribution, :reports_sensors])
    |> Repo.get(id)
  end

  @doc """
  Gets a report with all its relationships preloaded and prepared for JSON encoding.
  Returns a map that can be safely encoded to JSON.
  """
  def get_latest_report_data(report_id) do
    ReportData
    |> where([rd], rd.report_id == ^report_id)
    |> order_by([rd], desc: rd.generated_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_detail_json(id) do
    case get_detail(id) do
      nil ->
        nil
      report ->
        latest_data = get_latest_report_data(report.id)

        %{
          id: report.id,
          slug: report.slug,
          display_name: report.display_name,
          active_status: report.active_status,
          sample_interval: report.sample_interval,
          run_interval: report.run_interval,
          run_now_duration: report.run_now_duration,
          agg_function: report.agg_function,
          distribution: report.distribution,
          is_delete: report.is_delete,
          last_run_epoch: report.last_run_epoch,
          organization_id: report.organization_id,
          created_by_id: report.created_by_id,
          inserted_at: report.inserted_at,
          updated_at: report.updated_at,
          latest_report_data: if(latest_data, do: %{
            data: latest_data.data,
            generated_at: latest_data.generated_at,
            sample_interval: latest_data.sample_interval,
            agg_function: latest_data.agg_function
          }),
          organization: %{
            id: report.organization.id,
            name: report.organization.name
          },
          created_by: %{
            id: report.created_by.id,
            email: report.created_by.email
          },
          reports_distribution: Enum.map(report.reports_distribution, fn rd ->
            %{
              id: rd.id,
              report_id: rd.report_id,
              contact_type: rd.contact_type,
              contact_value: rd.contact_value,
              inserted_at: rd.inserted_at,
              updated_at: rd.updated_at
            }
          end),
          reports_sensors: Enum.map(report.reports_sensors, fn rs ->
            %{
              id: rs.id,
              sensor_uid: rs.sensor_uid,
              display_order: rs.display_order
            }
          end)
        }
    end
  end

  def update(report, attrs) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
  end

  @distribution_contact_type_user_uid "user_uid"
  @distribution_contact_type_email_address "email_address"

  def save_distribution(report_uid, distribution_enum, distribution_users, manual_email_distribution)do

    Repo.transaction(fn ->
      # Update the report's distribution type
      from(r in Report, where: r.id == ^report_uid)
      |> Repo.update_all(set: [distribution: distribution_enum])
      # Delete all existing distributions
      from(rd in ReportDistribution, where: rd.report_id == ^report_uid)
      |> Repo.delete_all()
      # Insert user distributions
      user_distributions =
        if is_list(distribution_users) && length(distribution_users) > 0 do
          distribution_users
          |> Enum.filter(&(is_integer(&1) && &1 > 0))
          |> Enum.map(fn user_uid ->
            %{
              report_id: report_uid,
              contact_type: @distribution_contact_type_user_uid,
              contact_value: to_string(user_uid),
              inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
              updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            }
          end)
        else
          []
        end

      # Insert email distributions
      email_distributions =
        if is_list(manual_email_distribution) && length(manual_email_distribution) > 0 do
          manual_email_distribution
          |> Enum.filter(&valid_email?/1)
          |> Enum.map(fn email ->
            %{
              report_id: report_uid,
              contact_type: @distribution_contact_type_email_address,
              contact_value: email,
              inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
              updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            }
          end)
        else
          []
        end
      # Bulk insert all distributions
      all_distributions = user_distributions ++ email_distributions
      if length(all_distributions) > 0 do
        Repo.insert_all(ReportDistribution, all_distributions)
      end

      {:ok, :distribution_saved}
    end)
  end



  def update_last_run(report) do
    case Repo.update_all(
      from(r in Report, where: r.id == ^report.id),
      set: [last_run_epoch: System.system_time(:second)]
    ) do
      {1, _} -> :ok
      _ -> {:error, :update_failed}
    end
  end

  def calculate_sample_count(report) do
    # Calculate number of samples based on sample interval
    # For example, if sample interval is 6 hours, we want enough samples to get a good average
    case report.sample_interval do
      :hour_1 -> 60  # One sample per minute
      :hour_2 -> 120
      :hour_4 -> 240
      :hour_6 -> 360
      :hour_12 -> 720
      :hour_24 -> 1440
      _ -> 60  # Default to one sample per minute
    end
  end

  def format_sensor_data(sensor_data) do
    sensor_data
    |> Enum.group_by(
      fn {run_day, _hour, _data} -> run_day end,
      fn {_run_day, hour, data} -> {hour, data} end
    )
    |> Enum.map(fn {day, hours_data} ->
      {day, Enum.into(hours_data, %{})}
    end)
    |> Enum.into(%{})
  end

  defp valid_email?(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.match?(~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/)
  end
  defp valid_email?(_), do: false

  def setup_report_directories(report) do
    reports_path = Application.get_env(:atlas, :reports_path)

    path = Path.join([
      reports_path,
      "reports",
      to_string(report.id)  # Convert report.id to string explicitly
    ])

    case File.mkdir_p(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, "Failed to create report directory: #{reason}"}
    end
  end

  def get_sensors(report_id) do
    query = from rs in Atlas.Reports.ReportSensor,
      where: rs.report_uid == ^report_id,
      order_by: [asc: rs.display_order],
      join: s in Atlas.Devices.Sensor,
      on: rs.sensor_uid == s.id,
      select: %{
        report_sensor: rs,
        sensor: s
      }

    sensors = Repo.all(query)
    {:ok, sensors}
  end

  def store_report_data(report_id, data, sample_interval \\ "hour_24", agg_function \\ "avg", generated_at \\ nil) do
    data_map = case data do
      data when is_map(data) -> data
      data when is_list(data) -> Enum.into(data, %{})
      _ -> %{data: data}
    end

    # Use provided generated_at or default to current time
    # parse_date returns {month, day, year}, convert to {year, month, day} for Date.new!
    generated_at_datetime = case generated_at do
      nil -> DateTime.utc_now()
      {month, day, year} -> DateTime.new!(Date.new!(year, month, day), ~T[00:00:00])
      datetime when is_struct(datetime, DateTime) -> datetime
      _ -> DateTime.utc_now()
    end

    attrs = %{
      report_id: report_id,
      data: data_map,
      sample_interval: if(sample_interval == "", do: "hour_24", else: sample_interval),
      agg_function: if(agg_function == "", do: "avg", else: agg_function),
      generated_at: generated_at_datetime
    }

    %ReportData{}
    |> ReportData.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, report_data} -> {:ok, report_data}
      {:error, changeset} ->
        {:error, "Failed to store report data: #{inspect(changeset.errors)}"}
    end
  end

  def get_report_data(report_id, sample_interval \\ nil, agg_function \\ nil) do
    ReportData
    |> where([rd], rd.report_id == ^report_id)
    |> maybe_filter_sample_interval(sample_interval)
    |> maybe_filter_agg_function(agg_function)
    |> order_by([rd], desc: rd.generated_at)
    |> limit(1)
    |> Repo.one()
  end

  def list_report_data(report_id, sample_interval \\ nil, agg_function \\ nil) do
    ReportData
    |> where([rd], rd.report_id == ^report_id)
    |> maybe_filter_sample_interval(sample_interval)
    |> maybe_filter_agg_function(agg_function)
    |> order_by([rd], desc: rd.generated_at)
    |> Repo.all()
  end

  def list_report_data_history(report_id, date_filter \\ nil) do
    query = ReportData
    |> where([rd], rd.report_id == ^report_id)

    query = if date_filter do
      # Filter by date if provided (format: "MM/DD/YYYY" or "MM-DD-YYYY")
      case parse_date_for_filter(date_filter) do
        {:ok, {year, month, day}} ->
          start_of_day = DateTime.new!(Date.new!(year, month, day), ~T[00:00:00])
          end_of_day = DateTime.new!(Date.new!(year, month, day), ~T[23:59:59])
          query
          |> where([rd], rd.generated_at >= ^start_of_day and rd.generated_at <= ^end_of_day)
        _ ->
          query
      end
    else
      query
    end

    query
    |> order_by([rd], desc: rd.generated_at)
    |> Repo.all()
  end

  defp parse_date_for_filter(date_string) when is_binary(date_string) do
    separator = if String.contains?(date_string, "/"), do: "/", else: "-"
    case String.split(date_string, separator) do
      [month, day, year] ->
        with {month, _} <- Integer.parse(month),
             {day, _} <- Integer.parse(day),
             {year, _} <- Integer.parse(year),
             true <- month in 1..12,
             true <- day in 1..31,
             true <- year >= 2000 do
          {:ok, {year, month, day}}
        else
          _ -> {:error, :invalid_date_format}
        end
      _ ->
        {:error, :invalid_date_format}
    end
  end
  defp parse_date_for_filter(_), do: {:error, :invalid_date_format}

  def run_scheduled_reports do
    # Get current date in MM-DD-YYYY format
    current_date = Date.utc_today() |> Calendar.strftime("%m-%d-%Y")

    # Get all active reports
    Report
    |> where([r], r.active_status == true)
    |> where([r], r.is_delete == false)
    |> Repo.all()
    |> Enum.each(fn report ->
      # Call the controller endpoint directly
      AtlasWeb.ReportController.run_report(
        %Plug.Conn{},  # empty conn
        %{
          "report_uid" => report.id,
          "date" => current_date
        }
      )
    end)
  end

  def list_active_reports do
    Report
    |> where([r], r.active_status == true)
    |> where([r], r.is_delete == false)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end

  def delete_report_data(%ReportData{} = report_data) do
    Repo.delete(report_data)
  end

  def get_report_data_by_id(report_data_id) do
    case Repo.get(ReportData, report_data_id) do
      nil -> {:error, :not_found}
      report_data -> {:ok, report_data}
    end
  end

  defp maybe_filter_sample_interval(query, nil), do: query
  defp maybe_filter_sample_interval(query, sample_interval) do
    where(query, [rd], rd.sample_interval == ^sample_interval)
  end

  defp maybe_filter_agg_function(query, nil), do: query
  defp maybe_filter_agg_function(query, agg_function) do
    where(query, [rd], rd.agg_function == ^agg_function)
  end

end

defmodule Atlas.Devices do
  @moduledoc """
  The Devices context.
  """

  import Ecto.Query, warn: false
  alias Atlas.Repo
  alias Atlas.Devices.{Device, Sensor, SensorDatum}

  alias Atlas.Devices.Model

  @doc """
  Returns the list of models.

  ## Examples

      iex> list_models()
      [%Model{}, ...]

  """
  def list_models do
    Repo.all(Model)
  end

  @doc """
  Gets a single model.

  Raises `Ecto.NoResultsError` if the Model does not exist.

  ## Examples

      iex> get_model!(123)
      %Model{}

      iex> get_model!(456)
      ** (Ecto.NoResultsError)

  """
  def get_model!(id), do: Repo.get!(Model, id)

  @doc """
  Creates a model.

  ## Examples

      iex> create_model(%{field: value})
      {:ok, %Model{}}

      iex> create_model(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_model(attrs \\ %{}) do
    %Model{}
    |> Model.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a model.

  ## Examples

      iex> update_model(model, %{field: new_value})
      {:ok, %Model{}}

      iex> update_model(model, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_model(%Model{} = model, attrs) do
    model
    |> Model.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a model.

  ## Examples

      iex> delete_model(model)
      {:ok, %Model{}}

      iex> delete_model(model)
      {:error, %Ecto.Changeset{}}

  """
  def delete_model(%Model{} = model) do
    Repo.delete(model)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking model changes.

  ## Examples

      iex> change_model(model)
      %Ecto.Changeset{data: %Model{}}

  """
  def change_model(%Model{} = model, attrs \\ %{}) do
    Model.changeset(model, attrs)
  end

  alias Atlas.Devices.Device

  @doc """
  Returns the list of devices for an organization with role-based filtering.
  """
  def get_devices(organization_id, role, user_id) do
    query = from d in Device,
      where: is_nil(d.deleted_at) and d.organization_id == ^organization_id


    query = if role == "user" do
      from d in query, where: d.user_id == ^user_id
    else
      query
    end

    Repo.all(query)
    |> Repo.preload(:sensors)
  end

  @doc """
  Returns the list of devices with alarm value 1 for an organization with role-based filtering.
  """
  def get_devices_with_alarm(organization_id, role, user_id) do
    query = from d in Device,
      where: is_nil(d.deleted_at) and d.organization_id == ^organization_id and d.alarm == 1

    query = if role == "user" do
      from d in query, where: d.user_id == ^user_id
    else
      query
    end

    Repo.all(query)
    |> Repo.preload(:sensors)
  end

  @doc """
  Gets a single device with its input sensors preloaded.

  Raises `Ecto.NoResultsError` if the Device does not exist.

  ## Examples

      iex> get_device!(123)
      %Device{}

      iex> get_device!(456)
      ** (Ecto.NoResultsError)

  """
  def get_device!(id),
  do:
    Repo.one(from d in Device, where: d.id == ^id and is_nil(d.deleted_at))
    |> Repo.preload(:sensors)


  def get_device_by_serial_number(serial_number) do
    Repo.one(
      from d in Device,
        where: d.serial_number == ^serial_number and is_nil(d.deleted_at),
        order_by: [desc: d.inserted_at],
        limit: 1
    )
  end

  @doc """
  Creates a device.

  ## Examples

      iex> create_device(%{field: value})
      {:ok, %Device{}}

      iex> create_device(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_device(attrs \\ %{}) do
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a device.

  ## Examples

      iex> update_device(device, %{field: new_value})
      {:ok, %Device{}}

      iex> update_device(device, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_device(%Device{} = device, attrs) do
    device
    |> Device.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a device.

  ## Examples

      iex> delete_device(device)
      {:ok, %Device{}}

      iex> delete_device(device)
      {:error, %Ecto.Changeset{}}

  """
  def delete_device(%Device{} = device) do
    Repo.delete(device)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking device changes.

  ## Examples

      iex> change_device(device)
      %Ecto.Changeset{data: %Device{}}

  """
  def change_device(%Device{} = device, attrs \\ %{}) do
    Device.changeset(device, attrs)
  end

  alias Atlas.Devices.Sensor

  @doc """
  Returns the list of sensors.

  ## Examples

      iex> list_sensors()
      [%Sensor{}, ...]

  """
  def list_sensors do
    Repo.all(Sensor)
  end

  @doc """
  Gets a single sensor.

  Raises `Ecto.NoResultsError` if the Sensor does not exist.

  ## Examples

      iex> get_sensor!(123)
      %Sensor{}

      iex> get_sensor!(456)
      ** (Ecto.NoResultsError)

  """
  def get_sensor!(id), do: Repo.get!(Sensor, id)

  @doc """
  Gets a sensor by device_id and channel.

  Returns nil if no sensor exists for the given device_id and channel.

  ## Examples

      iex> get_sensor_by_channel(123, "temperature")
      %Sensor{}

      iex> get_sensor_by_channel(456, "invalid")
      nil

  """
  def get_sensor_by_channel(device_id, channel) do
    Sensor
    |> where([s], s.device_id == ^device_id and s.channel == ^channel)
    |> Repo.one()
  end

  @doc """
  Creates a sensor.

  ## Examples

      iex> create_sensor(%{field: value})
      {:ok, %Sensor{}}

      iex> create_sensor(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_sensor(attrs \\ %{}) do
    %Sensor{}
    |> Sensor.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a sensor.

  ## Examples

      iex> update_sensor(sensor, %{field: new_value})
      {:ok, %Sensor{}}

      iex> update_sensor(sensor, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_sensor(%Sensor{} = sensor, attrs) do
    sensor
    |> Sensor.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a sensor.

  ## Examples

      iex> delete_sensor(sensor)
      {:ok, %Sensor{}}

      iex> delete_sensor(sensor)
      {:error, %Ecto.Changeset{}}

  """
  def delete_sensor(%Sensor{} = sensor) do
    Repo.delete(sensor)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sensor changes.

  ## Examples

      iex> change_sensor(sensor)
      %Ecto.Changeset{data: %Sensor{}}

  """
  def change_sensor(%Sensor{} = sensor, attrs \\ %{}) do
    Sensor.changeset(sensor, attrs)
  end

  alias Atlas.Devices.SensorDatum

  @doc """
  Returns the list of sensors_data.

  ## Examples

      iex> list_sensors_data()
      [%SensorDatum{}, ...]

  """
  def list_sensors_data do
    Repo.all(SensorDatum)
  end

  @doc """
  Gets a single sensor_datum.

  Raises `Ecto.NoResultsError` if the Sensor datum does not exist.

  ## Examples

      iex> get_sensor_datum!(123)
      %SensorDatum{}

      iex> get_sensor_datum!(456)
      ** (Ecto.NoResultsError)

  """
  def get_sensor_datum!(id), do: Repo.get!(SensorDatum, id)

  @doc """
  Creates a sensor_datum.

  ## Examples

      iex> create_sensor_datum(%{field: value})
      {:ok, %SensorDatum{}}

      iex> create_sensor_datum(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_sensor_datum(%Sensor{} = sensor, attrs \\ %{}) do
    %SensorDatum{}
    |> SensorDatum.changeset(Map.merge(attrs, %{sensor_id: sensor.id}))
    |> Repo.insert()
  end

  @doc """
  Updates a sensor_datum.

  ## Examples

      iex> update_sensor_datum(sensor_datum, %{field: new_value})
      {:ok, %SensorDatum{}}

      iex> update_sensor_datum(sensor_datum, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_sensor_datum(%SensorDatum{} = sensor_datum, attrs) do
    sensor_datum
    |> SensorDatum.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a sensor_datum.

  ## Examples

      iex> delete_sensor_datum(sensor_datum)
      {:ok, %SensorDatum{}}

      iex> delete_sensor_datum(sensor_datum)
      {:error, %Ecto.Changeset{}}

  """
  def delete_sensor_datum(%SensorDatum{} = sensor_datum) do
    Repo.delete(sensor_datum)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sensor_datum changes.

  ## Examples

      iex> change_sensor_datum(sensor_datum)
      %Ecto.Changeset{data: %SensorDatum{}}

  """
  def change_sensor_datum(%SensorDatum{} = sensor_datum, attrs \\ %{}) do
    SensorDatum.changeset(sensor_datum, attrs)
  end

  @doc """
  Updates a sensor's input_selected field by device_id and sensor_id.

  ## Examples

      iex> update_sensor_input_selected(1, 2, "new_input")
      {:ok, %Sensor{}}

      iex> update_sensor_input_selected(1, 999, "bad_input")
      {:error, :not_found}
  """
  def update_sensor_input_selected(device_id, sensor_id, input_selected) do
    case Repo.one(from s in Sensor, where: s.device_id == ^device_id and s.id == ^sensor_id) do
      nil -> {:error, :not_found}
      sensor -> update_sensor(sensor, %{input_selected: input_selected})
    end
  end

  def get_historical_data(sensor, start_time, stop_time, count, units \\ "english") do
    base_query = from(d in SensorDatum,
      where: d.sensor_id == ^sensor.sensor.id
    )

    # Always apply time range filtering if start_time and stop_time are provided
    query = if start_time && stop_time do
      base_query
      |> where([d], d.epoch >= ^start_time and d.epoch <= ^stop_time)
    else
      base_query
    end

    # Add ordering
    query = query
    |> order_by([d], asc: d.epoch)

    # Only apply limit if count is not -1 (which means get all data in the time range)
    query = if count != -1 do
      query |> limit(^count)
    else
      query
    end

    results = Repo.all(query)

    # Log the query results for debugging

    {:ok, results
    |> Enum.map(fn datum ->
      value = convert_units(datum.value, sensor, units)
      epoch_ms = if datum.epoch, do: datum.epoch * 1000, else: 1
      [epoch_ms, value, datum.is_alarm]
    end)}
  rescue
    error ->
      IO.inspect(error, label: "Error")
      {:error, "Failed to fetch historical data: #{inspect(error)}"}
  end

  defp convert_units(nil, _sensor, _units), do: nil
  defp convert_units(value, sensor, units) do
    # Convert Decimal to float if needed
    value = case value do
      %Decimal{} -> Decimal.to_float(value)
      _ -> value
    end

    case sensor.sensor.sensor_type_uid do
      1 -> # Temperature in °F/°C
        case units do
          "metric" -> (value - 32.0) * 5.0/9.0  # Convert °F to °C
          _ -> value                            # Keep as °F
        end
      2 -> value  # No conversion needed for humidity
      3 -> # Pressure in PSI/kPa
        case units do
          "metric" -> value * 6.89476  # Convert PSI to kPa
          _ -> value                   # Keep as PSI
        end
      4 -> # Flow in GPM/LPM
        case units do
          "metric" -> value * 3.78541  # Convert GPM to LPM
          _ -> value                   # Keep as GPM
        end
      _ -> value
    end
  end

  @doc """
  Gets sensor data for a specific sensor.

  ## Parameters
    - sensor_id: The ID of the sensor
    - limit: Optional limit for number of data points (default: 1)
    - order: Optional ordering (:asc or :desc, default: :desc)

  ## Returns
    - List of sensor data points
  """
  def get_sensor_data(sensor_id, limit \\ 1, order \\ :desc) do
    SensorDatum
    |> where([sd], sd.sensor_id == ^sensor_id)
    |> order_by([sd], [{^order, sd.epoch}])
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets all sensors of a device with their data.

  ## Parameters
    - device_id: The ID of the device
    - limit: Optional limit for number of data points per sensor (default: nil, gets all data)
    - order: Optional ordering (:asc or :desc, default: :desc)

  ## Returns
    - Device with sensors and their data
  """
  def get_device_sensors_with_data(device_id, limit \\ nil, order \\ :desc) do
    # Get device with sensors
    device = Repo.one(from d in Device,
      where: d.id == ^device_id and is_nil(d.deleted_at),
      preload: [:sensors]
    )

    if device && length(device.sensors) > 0 do
      sensor_ids = Enum.map(device.sensors, & &1.id)

      # Single optimized query to fetch ALL sensor data for all sensors at once
      # No date filtering - gets ALL historical data
      # Limit by default - gets 1 data point
      # Order by epoch (actual measurement time) not inserted_at to preserve precise timestamps
      base_query = from(sd in SensorDatum,
        where: sd.sensor_id in ^sensor_ids,
        where: is_nil(sd.deleted_at),
        order_by: [{^order, sd.epoch}]
      )

      # Apply limit only if specified (nil = get all data)
      query = if limit && limit > 0, do: base_query |> limit(^limit), else: base_query

      all_sensor_data = Repo.all(query)
      # Group sensor data by sensor_id for efficient lookup
      sensor_data_map = Enum.group_by(all_sensor_data, & &1.sensor_id)

      sensors_with_data =
        Enum.map(device.sensors, fn sensor ->
          data_for_sensor = Map.get(sensor_data_map, sensor.id, [])
          %{sensor | sensor_data: data_for_sensor}
        end)

      %{device | sensors: sensors_with_data}
    else
      device
    end
  end

end

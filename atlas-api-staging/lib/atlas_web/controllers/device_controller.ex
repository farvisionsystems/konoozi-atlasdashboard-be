defmodule AtlasWeb.DeviceController do
  use AtlasWeb, :controller

  alias Atlas.{Repo, Devices, Devices.Device, Devices.Sensor}

  def index(%{assigns: %{current_user: current_user}} = conn, _params) do
    user_org = hd(current_user.user_organizations)
    role = user_org.role.role

    devices = Devices.get_devices(current_user.organization_id, role, current_user.id)
    message = %{title: nil, body: "Successfully loaded Devices"}
    conn
    |> put_status(:created)
    |> json(%{devices: struct_into_map(devices), message: message})
  end

  @doc """
  Returns the list of devices with alarm value 1.
  """
  def alarm_devices(%{assigns: %{current_user: current_user}} = conn, _params) do
    user_org = hd(current_user.user_organizations)
    role = user_org.role.role

    devices = Devices.get_devices_with_alarm(current_user.organization_id, role, current_user.id)
    message = %{title: nil, body: "Successfully loaded devices with alarm"}
    conn
    |> put_status(:ok)
    |> json(%{devices: struct_into_map(devices), message: message})
  end

  @doc """
  Retrieves a device by ID and returns it with its input sensors.

  ## Parameters
    - id: The ID of the device to retrieve

  ## Returns
    - 200: Device found and returned successfully
    - 400: Device not found or unauthorized
  """
  def show(%{assigns: %{current_user: current_user}} = conn, %{"id" => id}) do
    with %Device{} = device <- Devices.get_device!(id),
         {:same_organization, true} <-
           {:same_organization, device.organization_id == current_user.organization_id} do
      message = %{title: nil, body: "Successfully loaded Device"}

      conn
      |> put_status(:ok)
      |> json(%{device: struct_into_map(device), message: message})
    else
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{message: "Device not found"}})
      {:same_organization, false} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{message: "Unauthorized access to device"}})
    end
  end

  def create(%{assigns: %{current_user: current_user}} = conn, params) do
    params = Map.put(params, "organization_id", current_user.organization_id)

    format? =
      params["serial_number"] != nil &&
        String.length(params["serial_number"]) == 12 &&
        String.match?(params["serial_number"], ~r/^\d+$/)

    with {:ok, true} <- {:ok, format?},
         {:ok, %Device{} = device} <-
           Devices.create_device(params) do
      message = %{title: nil, body: "Successfully added Device"}

      conn
      |> put_status(:created)
      |> json(%{device: struct_into_map(device), message: message})
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> json(%{error: error})

      {:ok, false} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{message: "Invalid serial_number format"}})
    end
  end

  def update(%{assigns: %{current_user: current_user}} = conn, params) do
    with %Device{} = device <- Devices.get_device!(params["id"]),
         {:same_organization, true} <-
           {:same_organization, device.organization_id == current_user.organization_id},
         {:ok, %Device{} = device} <-
           Devices.update_device(device, params) do
      message = %{title: nil, body: "Successfully updated Device"}

      conn
      |> put_status(:created)
      |> json(%{device: struct_into_map(device), message: message})
    else
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{message: "ID Not Found"}})

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> json(%{error: error})

      {:same_organization, false} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{message: "Something went wrong"}})
    end
  end

  def delete(%{assigns: %{current_user: current_user}} = conn, params) do
    with %Device{} = device <- Devices.get_device!(params["id"]),
         {:same_organization, true} <-
           {:same_organization, device.organization_id == current_user.organization_id},
         {:ok, %Device{} = device} <-
           Devices.update_device(device, %{deleted_at: DateTime.utc_now()}) do
      message = %{title: nil, body: "Successfully Deleted Device"}

      conn
      |> put_status(:created)
      |> json(%{device: struct_into_map(device), message: message})
    else
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{message: "ID Not Found"}})

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> json(%{error: error})

      {:same_organization, false} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{message: "Something went wrong"}})
    end
  end

  def update_sensor_inputs(%{assigns: %{current_user: current_user}} = conn, %{"sensors" => sensors}) do
    results = Enum.map(sensors, fn sensor ->
      with %Device{} = device <- Devices.get_device!(sensor["device_id"]),
           {:same_organization, true} <-
             {:same_organization, device.organization_id == current_user.organization_id},
           {:ok, updated} <-
             Devices.update_sensor_input_selected(device.id, sensor["sensor_id"], sensor["input_selected"]) do
        %{
          device_id: device.id,
          sensor_id: sensor["sensor_id"],
          status: "success"
        }
      else
        nil ->
          %{
            device_id: sensor["device_id"],
            sensor_id: sensor["sensor_id"],
            status: "error",
            message: "Device not found"
          }
        {:same_organization, false} ->
          %{
            device_id: sensor["device_id"],
            sensor_id: sensor["sensor_id"],
            status: "error",
            message: "Unauthorized"
          }
        {:error, error} ->
          %{
            device_id: sensor["device_id"],
            sensor_id: sensor["sensor_id"],
            status: "error",
            message: "Update failed"
          }
      end
    end)

    conn
    |> put_status(:ok)
    |> json(%{results: results})
  end

  @doc """
  Gets all sensors of a device with their latest data.

  ## Parameters
    - id: The ID of the device
    - limit: Optional limit for number of data points per sensor (default: 1)
    - order: Optional ordering (asc or desc, default: desc)

  ## Returns
    - 200: Device sensors and data found and returned successfully
    - 400: Device not found or unauthorized
  """
  def get_device_sensors(%{assigns: %{current_user: current_user}} = conn, %{"id" => device_id} = params) do
    # If limit is provided, use it; otherwise nil means get all data
    limit = case Map.get(params, "limit") do
      nil -> nil
      limit_str -> String.to_integer(limit_str)
    end
    order = Map.get(params, "order", "desc") |> String.to_atom()

    with %Device{} = device <- Devices.get_device_sensors_with_data(device_id, limit, order),
         {:same_organization, true} <-
           {:same_organization, device.organization_id == current_user.organization_id} do
      message = %{title: nil, body: "Successfully loaded device sensors and data"}

      conn
      |> put_status(:ok)
      |> json(%{device: struct_into_map(device), message: message})
    else
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{message: "Device not found"}})
      {:same_organization, false} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{message: "Unauthorized access to device"}})
    end
  end
end

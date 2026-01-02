defmodule Atlas.Cmd do
  @moduledoc """
  The Cmd context.
  """

  import Ecto.Query, warn: false
  alias Atlas.Repo

  alias Atlas.Cmd.Command

  @doc """
  Returns the list of commands_queue.

  ## Examples

      iex> list_commands_queue()
      [%Command{}, ...]

  """
  def list_commands_queue do
    Command
    |> join(:left, [c], d in Atlas.Devices.Device, on: c.device_id == d.id)
    |> select([c, d], %{
      status: c.status,
      inserted_at: c.inserted_at,
      serial_number: d.serial_number,
      command: c.command
    })
    |> Repo.all()
  end

  @doc """
  Gets a single command.

  Raises `Ecto.NoResultsError` if the Command does not exist.

  ## Examples

      iex> get_command!(123)
      %Command{}

      iex> get_command!(456)
      ** (Ecto.NoResultsError)

  """
  def get_command!(id), do: Repo.get!(Command, id)

  @doc """
  Creates a command.

  ## Examples

      iex> create_command(%{field: value})
      {:ok, %Command{}}

      iex> create_command(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_command(attrs \\ %{}) do
    %Command{}
    |> Command.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a command.

  ## Examples

      iex> update_command(command, %{field: new_value})
      {:ok, %Command{}}

      iex> update_command(command, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_command(%Command{} = command, attrs) do
    command
    |> Command.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates status of all commands with status 0 to 1 for a given mac_address and returns updated records.

  ## Examples

      iex> update_command_status("00:11:22:33:44:55")
      {:ok, [%Command{}]}

  """

  def update_command_status(serial_number) do
    Atlas.Devices.get_device_by_serial_number(serial_number)
    |> case do
      nil ->
        {:ok, []}

      device ->
        device_id = device.id

        query =
          from(c in Command,
            where: c.device_id == ^device_id and c.status == 0,
            select: c
          )

        case Repo.update_all(
               query,
               [set: [status: 1]],
               returning: [:id, :device_mac, :status]
             ) do
          {0, []} -> {:ok, []}
          {count, updated_commands} -> {:ok, updated_commands}
        end
    end
  end

  @doc """
  Deletes a command.

  ## Examples

      iex> delete_command(command)
      {:ok, %Command{}}

      iex> delete_command(command)
      {:error, %Ecto.Changeset{}}

  """
  def delete_command(%Command{} = command) do
    Repo.delete(command)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking command changes.

  ## Examples

      iex> change_command(command)
      %Ecto.Changeset{data: %Command{}}

  """
  def change_command(%Command{} = command, attrs \\ %{}) do
    Command.changeset(command, attrs)
  end

  @doc """
  Gets all pending commands for a specific model, ordered by id descending
  """
  def get_commands_by_device(device_id) do
    try do
      commands = Command
        |> where([c], c.device_id == ^device_id)
        |> where([c], c.status == 0)
        |> order_by([c], desc: c.id)
        |> Repo.all()

      case commands do
        [] ->
          {:ok, []}
        commands ->
          update_device_command_status(device_id)
          {:ok, commands}
      end
    rescue
      e in _ ->
        {:error, "Failed to fetch commands: #{inspect(e)}"}
    end
  end

  @doc """
  Updates status of all commands with status 0 to 1 for a given device_id
  """
  def update_device_command_status(device_id) do
    query = from(c in Command,
      where: c.device_id == ^device_id and c.status == 0
    )

    Repo.update_all(query, set: [status: 1])
  end


end

defmodule AtlasWeb.CommandController do
  use AtlasWeb, :controller
  alias Atlas.Cmd
  alias Atlas.Cmd.Command

  def create(conn, %{"command" => command_params}) do
    with {:ok, %Command{} = command} <- Cmd.create_command(command_params) do
      conn
      |> put_status(:created)
      |> json(%{command: command.id})
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: translate_errors(changeset)})

      error ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create command: #{inspect(error)}"})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, command} <- {:ok, Cmd.get_command!(id)},
         {:ok, %Command{}} <- Cmd.delete_command(command) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Command not found"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: translate_errors(changeset)})

      error ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to delete command: #{inspect(error)}"})
    end
  end

  def index(conn, _params) do
    commands = Cmd.list_commands_queue()
    json(conn, %{commands: commands})
  end
end

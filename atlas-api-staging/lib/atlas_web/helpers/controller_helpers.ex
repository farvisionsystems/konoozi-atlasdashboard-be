defmodule AtlasWeb.Helpers.ControllerHelpers do
  @moduledoc """
  Controller Helper Functions
  """
  @spec changeset_error(struct()) :: tuple()
  def changeset_error(%Ecto.Changeset{errors: errors}) do
    Enum.map(errors, fn {key, {msg, _}} -> "#{key}: #{msg}" end)
  end

  def translate_errors(struct) do
    Ecto.Changeset.traverse_errors(struct, &AtlasWeb.ErrorHelpers.translate_error/1)
  end

  def changeset_error(err), do: err |> error()

  @spec error(any()) :: tuple()
  def error(data \\ "Doesn't Exist!")

  def error(data) when is_tuple(data), do: data

  def error(nil), do: {:error, "Doesn't Exist!"}

  def error(err), do: {:error, err}
end

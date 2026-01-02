defmodule Atlas.TimezoneAdjuster do
  import Ecto.Changeset
  import Timex

  @moduledoc """
  Module to adjust the timestamp fields in a changeset based on timezone difference.
  """

  # Adjusts multiple timestamp fields in a changeset by timezone difference in hours
  def adjust_datetime(changeset, timezone_offset, fields) do
    Enum.reduce(fields, changeset, fn field, acc_changeset ->
      case get_field(acc_changeset, field) || DateTime.utc_now() do
        %DateTime{} = datetime ->
          adjusted_datetime =
            datetime
            |> Timex.shift(hours: timezone_offset)
            |> DateTime.truncate(:second)

          put_change(acc_changeset, field, adjusted_datetime)

        _error ->
          acc_changeset
      end
    end)
  end
end

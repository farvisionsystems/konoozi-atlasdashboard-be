defmodule AtlasWeb.UserAlarmSettingsController do
  use AtlasWeb, :controller
  alias Atlas.Accounts

  def update(conn, params) do
    current_user = conn.assigns.current_user

    alarm_settings = %{
      general_alarm_email_enabled: params["general_alarm_email_enabled"],
      general_alarm_push_enabled: params["general_alarm_push_enabled"],
      general_alarm_location_preference: params["general_alarm_location_preference"]
    }

    case Accounts.update_user_alarm_settings(current_user, alarm_settings) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "success",
          message: "User alarm settings updated successfully",
          user: %{
            id: updated_user.id,
            email: updated_user.email,
            general_alarm_email_enabled: updated_user.general_alarm_email_enabled,
            general_alarm_push_enabled: updated_user.general_alarm_push_enabled,
            general_alarm_location_preference: updated_user.general_alarm_location_preference
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          status: "error",
          message: "Failed to update user alarm settings",
          errors: format_changeset_errors(changeset)
        })
    end
  end

  def show(conn, _params) do
    current_user = conn.assigns.current_user

    conn
    |> put_status(:ok)
    |> json(%{
      status: "success",
      user: %{
        id: current_user.id,
        email: current_user.email,
        general_alarm_email_enabled: current_user.general_alarm_email_enabled,
        general_alarm_push_enabled: current_user.general_alarm_push_enabled,
        general_alarm_location_preference: current_user.general_alarm_location_preference
      }
    })
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

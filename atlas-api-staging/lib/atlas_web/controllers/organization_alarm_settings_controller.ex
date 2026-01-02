defmodule AtlasWeb.OrganizationAlarmSettingsController do
  use AtlasWeb, :controller
  alias Atlas.Organizations

  def update(conn, %{"id" => organization_id} = params) do
    organization = Organizations.get_organization!(organization_id)
    current_user = conn.assigns.current_user

    # Check if user has permission to update organization settings
    if can_modify_organization?(current_user, organization) do
      alarm_settings = %{
        general_alarm_email_enabled: params["general_alarm_email_enabled"],
        general_alarm_push_enabled: params["general_alarm_push_enabled"],
        general_alarm_sms_enabled: params["general_alarm_sms_enabled"],
        general_alarm_location_preference: params["general_alarm_location_preference"]
      }

      case Organizations.update_organization_alarm_settings(organization.id, alarm_settings) do
        {:ok, updated_organization} ->
          conn
          |> put_status(:ok)
          |> json(%{
            status: "success",
            message: "Organization alarm settings updated successfully",
            organization: %{
              id: updated_organization.id,
              name: updated_organization.name,
              general_alarm_email_enabled: updated_organization.general_alarm_email_enabled,
              general_alarm_push_enabled: updated_organization.general_alarm_push_enabled,
              general_alarm_sms_enabled: updated_organization.general_alarm_sms_enabled,
              general_alarm_location_preference: updated_organization.general_alarm_location_preference
            }
          })

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            status: "error",
            message: "Failed to update organization alarm settings",
            errors: format_changeset_errors(changeset)
          })
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{
        status: "error",
        message: "You don't have permission to update this organization's alarm settings"
      })
    end
  end

  def show(conn, %{"id" => organization_id}) do
    organization = Organizations.get_organization!(organization_id)
    current_user = conn.assigns.current_user

    if can_modify_organization?(current_user, organization) do
      conn
      |> put_status(:ok)
      |> json(%{
        status: "success",
        organization: %{
          id: organization.id,
          name: organization.name,
          general_alarm_email_enabled: organization.general_alarm_email_enabled,
          general_alarm_push_enabled: organization.general_alarm_push_enabled,
          general_alarm_sms_enabled: organization.general_alarm_sms_enabled,
          general_alarm_location_preference: organization.general_alarm_location_preference
        }
      })
    else
      conn
      |> put_status(:forbidden)
      |> json(%{
        status: "error",
        message: "You don't have permission to view this organization's alarm settings"
      })
    end
  end

  defp can_modify_organization?(current_user, organization) do
    user_org = Atlas.Accounts.get_user_organization(current_user.id, organization.id)

    case user_org do
      nil -> false
      user_org ->
        case user_org.role.role do
          "super_admin" -> true
          "admin" -> true
          _ -> false
        end
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

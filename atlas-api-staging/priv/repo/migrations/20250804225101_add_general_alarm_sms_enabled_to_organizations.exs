defmodule Atlas.Repo.Migrations.AddGeneralAlarmSmsEnabledToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :general_alarm_sms_enabled, :boolean, default: true
    end
  end
end

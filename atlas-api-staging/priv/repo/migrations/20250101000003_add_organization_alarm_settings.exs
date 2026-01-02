defmodule Atlas.Repo.Migrations.AddOrganizationAlarmSettings do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :general_alarm_email_enabled, :boolean, default: true
      add :general_alarm_push_enabled, :boolean, default: true
      add :general_alarm_location_preference, :boolean, default: false
    end
  end
end

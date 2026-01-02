defmodule Atlas.Repo.Migrations.AddDeviceAlarmSettings do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :alarm_email_enabled, :boolean, default: true
      add :alarm_push_enabled, :boolean, default: true
      add :alarm_location_preference, :boolean, default: false
    end
  end
end

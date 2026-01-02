defmodule Atlas.Repo.Migrations.AddDeviceAlarmContactFields do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :alarm_notification_email, :string
      add :alarm_notification_phone, :string
      add :alarm_sms_enabled, :boolean, default: false
    end
  end
end

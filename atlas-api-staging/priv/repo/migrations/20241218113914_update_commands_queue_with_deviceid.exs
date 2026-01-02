defmodule Atlas.Repo.Migrations.UpdateCommandsQueueWithDeviceid do
  use Ecto.Migration

  def change do
    # Modify the commands_queue table
    alter table(:commands_queue) do
      # Remove the device_mac field
      remove :device_mac
      # Add device_id reference to devices table
      add :device_id, references(:devices, on_delete: :nothing)
    end

    # Modify the devices table
    alter table(:devices) do
      # Add the image field of type string
      add :image, :string
    end
  end
end

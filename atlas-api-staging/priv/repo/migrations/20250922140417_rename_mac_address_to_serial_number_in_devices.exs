defmodule Atlas.Repo.Migrations.RenameMacAddressToSerialNumberInDevices do
  use Ecto.Migration

  def change do
    # Rename the column from mac_address to serial_number
    rename table(:devices), :mac_address, to: :serial_number
  end
end

defmodule Atlas.Repo.Migrations.AddMigrationchange do
  use Ecto.Migration

  def change do
    # First alter the column type to text
    alter table(:reports_distribution) do
      modify :contact_type, :string
    end
  end
end

defmodule Atlas.Repo.Migrations.Alterdatatype do
  use Ecto.Migration

  def change do
    # Drop existing foreign key constraints first
    drop constraint(:reports, "reports_organization_id_fkey")

    alter table(:reports) do
      modify :organization_id, :bigint
      modify :created_by_id, :bigint
    end
  end
end

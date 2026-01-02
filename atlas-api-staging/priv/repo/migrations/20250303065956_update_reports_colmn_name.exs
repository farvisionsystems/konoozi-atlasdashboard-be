defmodule Atlas.Repo.Migrations.UpdateReportsColmnName do
  use Ecto.Migration

  def change do
    rename table(:reports), :created_by, to: :created_by_id
  end

end

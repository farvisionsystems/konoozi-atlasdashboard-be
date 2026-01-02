defmodule Atlas.Repo.Migrations.AddParentIdAsForeignKey do
  use Ecto.Migration

  def up do
    alter table(:messages) do
      remove :parent_id

      add :parent_id, references(:messages, on_delete: :nilify_all)
    end
  end

  def down do
    alter table(:messages) do
      remove :parent_id

      add :parent_id, :integer
    end
  end
end

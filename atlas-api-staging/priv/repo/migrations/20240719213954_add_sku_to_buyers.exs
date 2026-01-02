defmodule Atlas.Repo.Migrations.AddSkuToBuyers do
  use Ecto.Migration

  def change do
    alter table(:buyers) do
      add :sku, :string
    end

    create unique_index(:buyers, [:sku])
  end
end

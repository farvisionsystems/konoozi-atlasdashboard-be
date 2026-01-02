defmodule Atlas.Repo.Migrations.RemoveTimelineFromBuyerNeed do
  use Ecto.Migration

  @timeline "buyer_rental_timeline"

  def up do
    execute "DROP TYPE IF EXISTS #{@timeline} CASCADE;"
    execute "DROP TYPE IF EXISTS timeline CASCADE;"

    alter table(:buyer_needs) do
      remove :timeline
    end
  end
end

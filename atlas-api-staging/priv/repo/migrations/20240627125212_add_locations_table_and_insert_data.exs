defmodule Atlas.Repo.Migrations.AddLocationsTableAndInsertData do
  use Ecto.Migration

  @csv_file "priv/repo/csv/usa_locations.csv"

  def up do
    create table(:locations, primary_key: false) do
      add :zip_code, :string, primary_key: true
      add :city_name, :string
      add :state_id, :string
      add :state_name, :string
    end

    path = Application.app_dir(:atlas, @csv_file)

    path
    |> File.stream!()
    |> CSV.decode!()
    |> Enum.each(fn [zip_code, city_name, state_id, state_name] ->
      execute(
        "INSERT INTO locations (zip_code, city_name, state_id, state_name) VALUES ('#{zip_code}', '#{city_name}', '#{state_id}', '#{state_name}')"
      )
    end)
  end

  def down do
    drop(table(:locations))
  end
end

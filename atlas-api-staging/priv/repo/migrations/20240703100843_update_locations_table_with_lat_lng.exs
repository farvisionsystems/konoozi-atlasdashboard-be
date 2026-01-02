defmodule Atlas.Repo.Migrations.UpdateLocationsTableWithLatLng do
  use Ecto.Migration

  @csv_file "priv/repo/csv/us_locations.csv"

  def up do
    drop_if_exists(table(:locations))

    # execute("CREATE EXTENSION IF NOT EXISTS postgis")
    # execute("CREATE EXTENSION IF NOT EXISTS citext", "")

    create table(:locations, primary_key: false) do
      add :zip_code, :string, primary_key: true
      add :city_name, :string
      add :latitude, :float
      add :longitude, :float
      add :state_id, :string
      add :state_name, :string
    end

    path = Application.app_dir(:atlas, @csv_file)

    path
    |> File.stream!()
    |> CSV.decode!()
    |> Enum.each(fn [zip_code, latitude, longitude, city_name, state_id, state_name] ->
      zip_code =
        zip_code
        |> Integer.parse()
        |> case do
          {int_value, _} ->
            int_value
            |> Integer.to_string()
            |> String.pad_leading(5, "0")

          :error ->
            zip_code
        end

      execute(
        "INSERT INTO locations (zip_code, latitude, longitude, city_name, state_id, state_name) VALUES ('#{zip_code}', #{latitude}, #{longitude}, '#{city_name}', '#{state_id}', '#{state_name}')"
      )
    end)
  end

  def down do
    drop(table(:locations))
  end
end

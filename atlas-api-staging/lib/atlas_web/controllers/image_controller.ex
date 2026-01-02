defmodule AtlasWeb.ImageController do
  use AtlasWeb, :controller
  alias Atlas.Images.Image
  alias Atlas.Images

  def create(conn, %{"image" => %{path: path, filename: filename}} = image_params) do
    with {:allowed_extension?, true} <-
           {:allowed_extension?, Path.extname(filename) in [".jpg", ".jpeg", ".png", ".gif"]},
         {:ok, image} <- Images.create_image(image_params) do
      conn
      |> put_status(:created)
      |> render("show.json", image: image)
    else
      {:allowed_extension?, _} ->
        conn
        |> put_status(:bad_request)
        |> render("error.json",
          error: "Invalid image format. Only .jpg, .jpeg, .png, and .gif are allowed."
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)

        conn
        |> put_status(:bad_request)
        |> render("error.json", error: error)

      _ ->
        conn
        |> put_status(:bad_request)
        |> render("error.json",
          error: "Invalid image format. Only .jpg, .jpeg, .png, and .gif are allowed."
        )
    end
  end
end

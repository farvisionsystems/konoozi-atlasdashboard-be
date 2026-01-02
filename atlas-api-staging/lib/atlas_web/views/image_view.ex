defmodule AtlasWeb.ImageView do
  use AtlasWeb, :view
  alias AtlasWeb.ImageView

  def render("show.json", %{image: image}) do
    message = %{title: nil, body: "Successfully Uploaded image"}
    %{data: render_one(image, ImageView, "image.json"), message: message}
  end

  def render("image.json", %{image: image}) do
    %{
      image_url: get_url(image.image.file_name)
    }
  end

  def render("error.json", %{error: error}) do
    %{error: error}
  end

  defp get_url(image) do
    # TODO: remove hardcoded
    # AtlasWeb.Endpoint.url() 
    "https://atlassensordashboard.com" <> Atlas.ImageUploader.url(image)
  end
end

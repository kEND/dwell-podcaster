defmodule PodcasterWeb.PodcastController do
  use PodcasterWeb, :controller
  alias Podcaster.{Scraper, RSSGenerator, Cache}

  def show(conn, %{"guid" => guid}) do
    case generate_feed(guid) do
      {:ok, rss} ->
        conn
        |> put_resp_content_type("application/rss+xml")
        |> send_resp(200, rss)
      {:error, _message} ->
        conn
        |> put_status(:not_found)
        |> text("Feed not found")
    end
  end

  defp generate_feed(guid) do
    case Cache.get(guid) do
      nil ->
        case Scraper.scrape_series(guid) do
          {:ok, series} ->
            rss = RSSGenerator.generate_feed(series)
            Cache.put(guid, rss)
            {:ok, rss}
          {:error, message} ->
            {:error, message}
        end
      rss ->
        {:ok, rss}
    end
  end
end

defmodule PodcasterWeb.PodcastLive do
  use PodcasterWeb, :live_view
  alias Podcaster.{Scraper, RSSGenerator, Cache}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, url: "", rss: nil, error: nil)}
  end

  def handle_event("generate", %{"url" => url}, socket) do
    series_guid = extract_series_guid(url)

    case Cache.get(series_guid) do
      nil ->
        case generate_feed(series_guid) do
          {:ok, rss} ->
            Cache.put(series_guid, rss)
            {:noreply, assign(socket, url: url, rss: rss, error: nil)}

          {:error, message} ->
            {:noreply, assign(socket, url: url, error: message, rss: nil)}
        end

      rss ->
        {:noreply, assign(socket, url: url, rss: rss, error: nil)}
    end
  end

  defp generate_feed(series_guid) do
    IO.inspect(series_guid, label: "series_guid")

    case Scraper.scrape_series(series_guid) do
      {:ok, series} ->
        {:ok, RSSGenerator.generate_feed(series)}

      {:error, message} ->
        {:error, message}
    end
  end

  defp extract_series_guid(url) do
    uri = URI.parse(url)
    query = URI.decode_query(uri.query || "")
    query["series"]
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Podcast RSS Generator</h1>
      <form phx-submit="generate">
        <input type="text" name="url" value={@url} placeholder="Enter series URL" />
        <button type="submit">Generate RSS</button>
      </form>

      <%= if @error do %>
        <p class="error"><%= @error %></p>
      <% end %>

      <%= if @rss do %>
        <h2>Generated RSS Feed</h2>
        <pre><%= @rss %></pre>
      <% end %>
    </div>
    """
  end
end

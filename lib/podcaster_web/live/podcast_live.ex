defmodule PodcasterWeb.PodcastLive do
  use PodcasterWeb, :live_view
  alias Podcaster.{Scraper, RSSGenerator, Cache}

  def mount(%{"guid" => guid}, _session, socket) do
    case generate_feed(guid) do
      {:ok, _rss} ->
        {:ok, assign(socket, guid: guid, feed_url: feed_url(guid), error: nil)}
      {:error, message} ->
        {:ok, assign(socket, guid: guid, feed_url: nil, error: message)}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, guid: "", feed_url: nil, error: nil)}
  end

  def handle_event("generate", %{"url_or_guid" => url_or_guid}, socket) do
    guid = extract_guid(url_or_guid)

    case generate_feed(guid) do
      {:ok, rss} ->
        Cache.put(guid, rss)
        {:noreply, push_redirect(socket, to: "/#{guid}")}
      {:error, message} ->
        {:noreply, assign(socket, guid: guid, feed_url: nil, error: message)}
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

  defp extract_guid(url_or_guid) do
    case URI.parse(url_or_guid) |> IO.inspect(label: "URI.parse") do
      %URI{host: "www.dwellcc.org", query: query} when not is_nil(query) ->
        URI.decode_query(query)["series"] |> IO.inspect(label: "URI.decode_query")
      _ ->
        url_or_guid
    end
  end

  defp feed_url(guid) do
    ~p"/feed/#{guid}"
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Podcast RSS Generator</h1>
      <form phx-submit="generate">
        <input type="text" name="url_or_guid" value={@guid} placeholder="Enter series URL or GUID" />
        <button type="submit">Generate RSS</button>
      </form>

      <%= if @error do %>
        <p class="error"><%= @error %></p>
      <% end %>

      <%= if @feed_url do %>
        <h2>Generated RSS Feed</h2>
        <p>Your RSS feed is ready! You can access it at:</p>
        <a href={@feed_url} target="_blank"><%= @feed_url %></a>
      <% end %>
    </div>
    """
  end
end

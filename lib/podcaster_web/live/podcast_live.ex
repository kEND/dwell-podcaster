defmodule PodcasterWeb.PodcastLive do
  use PodcasterWeb, :live_view
  alias Podcaster.{Scraper, RSSGenerator, Cache}

  def mount(%{"guid" => guid}, _session, socket) do
    case generate_feed(guid) do
      {:ok, _rss} ->
        {:ok, assign(socket, guid: guid, feed_url: feed_url(guid, socket), error: nil)}
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
        {:noreply, assign(socket, guid: guid, feed_url: feed_url(guid, socket), error: message)}
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

  defp feed_url(guid, _socket) do
    base_url = PodcasterWeb.Endpoint.url()
    Path.join(base_url, "/feed/#{guid}")
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
        <div class="flex items-center">
          <a href={@feed_url} target="_blank" class="mr-2"><%= @feed_url %></a>
          <button phx-hook="CopyToClipboard" id="copy-button" data-clipboard-text={@feed_url}
                  class="text-gray-500 hover:text-gray-700">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.666 3.888A2.25 2.25 0 0013.5 2.25h-3c-1.03 0-1.9.693-2.166 1.638m7.332 0c.055.194.084.4.084.612v0a.75.75 0 01-.75.75H9a.75.75 0 01-.75-.75v0c0-.212.03-.418.084-.612m7.332 0c.646.049 1.288.11 1.927.184 1.1.128 1.907 1.077 1.907 2.185V19.5a2.25 2.25 0 01-2.25 2.25H6.75A2.25 2.25 0 014.5 19.5V6.257c0-1.108.806-2.057 1.907-2.185a48.208 48.208 0 011.927-.184" />
            </svg>
          </button>
        </div>
      <% end %>
    </div>
    """
  end
end

defmodule Podcaster.RSSGeneratorTest do
  use ExUnit.Case, async: true
  alias Podcaster.RSSGenerator
  alias Podcaster.Scraper.{Series, Teaching}

  describe "generate_feed/1" do
    test "generates a valid RSS feed for a series" do
      series = %Series{
        title: "Test Series",
        link: "https://example.com/series/1",
        description: "A test series description",
        image_url: "https://example.com/series/1/image.jpg",
        teachings: [
          %Teaching{
            title: "Test Teaching 1",
            url: "https://example.com/teaching/1",
            guid: "https://example.com/teaching/1",
            pub_date: ~N[2023-01-01 12:00:00],
            description: "Test teaching 1 description",
            author: "John Doe",
            audio_url: "https://example.com/teaching/1/audio.mp3",
            subtitle: "Test subtitle 1",
            duration: 1800,
            explicit: "no",
            image_url: "https://example.com/teaching/1/image.jpg",
            episode_type: "full",
            block: false
          },
          %Teaching{
            title: "Test Teaching 2",
            url: "https://example.com/teaching/2",
            guid: "https://example.com/teaching/2",
            pub_date: ~N[2023-01-02 12:00:00],
            description: "Test teaching 2 description",
            author: "Jane Doe",
            audio_url: "https://example.com/teaching/2/audio.mp3",
            subtitle: "Test subtitle 2",
            duration: 2400,
            explicit: "no",
            image_url: "https://example.com/teaching/2/image.jpg",
            episode_type: "full",
            block: true
          }
        ]
      }

      rss_feed = RSSGenerator.generate_feed(series)

      assert is_binary(rss_feed)
      assert String.starts_with?(rss_feed, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
      assert String.contains?(rss_feed, "<rss version=\"2.0\"")
      assert String.contains?(rss_feed, "<channel>")
      assert String.contains?(rss_feed, "<title>Test Series</title>")
      assert String.contains?(rss_feed, "<link>https://example.com/series/1</link>")
      assert String.contains?(rss_feed, "<description>A test series description</description>")
      assert String.contains?(rss_feed, "<language>en-us</language>")
      assert String.contains?(rss_feed, "<copyright>© #{DateTime.utc_now().year} Dwell Community Church</copyright>")
      assert String.contains?(rss_feed, "<pubDate>")
      assert String.contains?(rss_feed, "<lastBuildDate>")
      assert String.contains?(rss_feed, "<image>")
      assert String.contains?(rss_feed, "<url>https://example.com/series/1/image.jpg</url>")

      # Test for individual items
      assert String.contains?(rss_feed, "<item>")
      assert String.contains?(rss_feed, "<title>Test Teaching 1</title>")
      assert String.contains?(rss_feed, "<link>https://example.com/teaching/1</link>")
      assert String.contains?(rss_feed, "<guid isPermaLink=\"false\">https://example.com/teaching/1</guid>")
      assert String.contains?(rss_feed, "<pubDate>Sun, 01 Jan 2023 12:00:00 GMT</pubDate>")
      assert String.contains?(rss_feed, "<description><![CDATA[Test teaching 1 description]]></description>")
      assert String.contains?(rss_feed, "<author>John Doe</author>")
      assert String.contains?(rss_feed, "<enclosure url=\"https://example.com/teaching/1/audio.mp3\" length=\"0\" type=\"audio/mpeg\"/>")
      assert String.contains?(rss_feed, "<itunes:author>John Doe</itunes:author>")
      assert String.contains?(rss_feed, "<itunes:subtitle>Test subtitle 1</itunes:subtitle>")
      assert String.contains?(rss_feed, "<itunes:duration>00:30:00</itunes:duration>")
      assert String.contains?(rss_feed, "<itunes:explicit>no</itunes:explicit>")
      assert String.contains?(rss_feed, "<itunes:image href=\"https://example.com/teaching/1/image.jpg\"/>")
      assert String.contains?(rss_feed, "<itunes:episodeType>full</itunes:episodeType>")

      # Test for the second item
      assert String.contains?(rss_feed, "<title>Test Teaching 2</title>")
      assert String.contains?(rss_feed, "<link>https://example.com/teaching/2</link>")
      assert String.contains?(rss_feed, "<itunes:block>yes</itunes:block>")
    end
  end
end

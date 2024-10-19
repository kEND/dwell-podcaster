defmodule Podcaster.ScraperTest do
  use ExUnit.Case, async: true
  alias Podcaster.Scraper
  alias Podcaster.Scraper.{Series, Teaching}
  import Mox

  # Set up the mock expectations before each test
  setup :verify_on_exit!

  @series_guid "f17f7277-25f4-70f0-c472-651788981d26"
  @teaching_fixture "test/fixtures/teaching.html"

  describe "scrape_series/1" do
    test "fetches and parses series data" do
      api_url =
        "https://www.dwellcc.org/api/org.dwellcc/TeachingFinder/TeachingSearch?SearchSeriesGuid=#{@series_guid}&ItemsPerPage=100&PageNumber=1"

      expect(MockHTTPoison, :get, fn ^api_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "Series" => [%{"SeriesName" => "Hebrews", "SeriesGuid" => @series_guid}],
               "Teachings" => [
                 %{"Title" => "Introduction", "CanonicalUrl" => "/teaching/4184"},
                 %{"Title" => "Jesus is Better", "CanonicalUrl" => "/teaching/4194"}
               ]
             })
         }}
      end)

      # Mock responses for individual teachings
      Enum.each(["/teaching/4184", "/teaching/4194"], fn teaching_url ->
        expect(MockHTTPoison, :get, fn "https://www.dwellcc.org" <> ^teaching_url ->
          {:ok, %HTTPoison.Response{status_code: 200, body: File.read!(@teaching_fixture)}}
        end)
      end)

      {:ok, %Series{} = series} = Scraper.scrape_series(@series_guid)

      assert series.title == "Hebrews"
      assert series.link == "https://www.dwellcc.org/teachings?series=#{@series_guid}"
      assert series.description == "Teachings from Dwell Community Church - Hebrews"
      assert length(series.teachings) == 2

      Enum.each(series.teachings, fn teaching ->
        assert %Teaching{} = teaching
        assert teaching.title in ["Introduction", "Jesus is Better"]
        assert teaching.audio_url == "https://www.dwellcc.org/media/10BCD360-20F1-E2F3-0F12-B5B3B44BD18F.m4a"
        assert teaching.author == "Dennis McCallum"
      end)
    end

    test "handles errors when fetching series data" do
      api_url =
        "https://www.dwellcc.org/api/org.dwellcc/TeachingFinder/TeachingSearch?SearchSeriesGuid=#{@series_guid}&ItemsPerPage=100&PageNumber=1"

      expect(MockHTTPoison, :get, fn ^api_url ->
        {:error, %HTTPoison.Error{reason: "network error"}}
      end)

      assert {:error, "HTTP request failed: network error"} = Scraper.scrape_series(@series_guid)
    end
  end

  describe "scrape_teaching/1" do
    test "extracts teaching data from a teaching page" do
      teaching_data = %{
        "CanonicalUrl" => "/teaching/4184",
        "Title" => "Introduction",
        "TeachingGuid" => "4184",
        "TitleAbbr" => "Intro"
      }

      teaching_url = "https://www.dwellcc.org/teaching/4184"

      expect(MockHTTPoison, :get, fn ^teaching_url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: """
             <html>
               <script type="application/ld+json">
                 {
                   "datePublished": "07/12/2015",
                   "abstract": "The God of the Bible is unique in His desire to communicate...",
                   "author": {"name": "Dennis McCallum", "image": "/GetImage.ashx?guid=ef9b2d1a-afca-451d-825c-81abad617162"},
                   "hasPart": [{"contentUrl": "https://www.dwellcc.org/media/10BCD360-20F1-E2F3-0F12-B5B3B44BD18F.m4a"}],
                   "url": "https://www.dwellcc.org/teaching/4184"
                 }
               </script>
             </html>
           """
         }}
      end)

      assert %Teaching{} = teaching = Scraper.scrape_teaching(teaching_data)

      assert teaching.title == "Introduction"
      assert teaching.description == "The God of the Bible is unique in His desire to communicate..."
      assert teaching.pub_date == "2015-07-12T00:00:00Z"
      assert teaching.audio_url == "https://www.dwellcc.org/media/10BCD360-20F1-E2F3-0F12-B5B3B44BD18F.m4a"
      assert teaching.guid == "4184"
      assert teaching.author == "Dennis McCallum"
      assert teaching.subtitle == "Intro"
      assert teaching.image_url == "https://www.dwellcc.org/GetImage.ashx?guid=ef9b2d1a-afca-451d-825c-81abad617162"
      assert teaching.url == "https://www.dwellcc.org/teaching/4184"
      # 1h30m in seconds
      assert teaching.duration == "PT36M07S"
    end

    test "handles errors when fetching teaching data" do
      teaching_data = %{"CanonicalUrl" => "/teaching/4184", "Title" => "Introduction", "TeachingGuid" => "4184"}
      teaching_url = "https://www.dwellcc.org/teaching/4184"

      expect(MockHTTPoison, :get, fn ^teaching_url ->
        {:error, %HTTPoison.Error{reason: "network error"}}
      end)

      assert {:error, "Failed to fetch teaching: %HTTPoison.Error{reason: \"network error\", id: nil}"} =
               Scraper.scrape_teaching(teaching_data)
    end
  end
end

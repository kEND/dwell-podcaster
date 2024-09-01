# Podcaster

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

## User Stories

- As a user, I want to be able to paste in a URL of a teaching series and hit submit to be taken to an RSS feed of the podcasts in that series.
  - an example input is https://www.dwellcc.org/teachings?series=f17f7277-25f4-70f0-c472-651788981d26
  - a representative series page is `test/fixtures/series-list.html`
  - series pages are often paginated, so we should expect multiple pages of results
  - the key data on the series page is the teaching id for each teaching
  - gather the ordered list of teaching ids from all pages in the series
  - render an RSS feed of episodes, one episode per teaching id
    - the necessary data for each episode can be found on its teaching page in a script tag with the type `application/ld+json`
    - an example teaching page URL is https://www.dwellcc.org/teaching/4184
    - a representative teaching page is `test/fixtures/heb-intro.html`

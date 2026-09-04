defmodule EmakolaWeb.StoreGone do
  @moduledoc """
  Raised when a request reaches an archived shop.

  Plug turns it into a 410 Gone. A redirect would tell search engines the
  shop moved and keep its URLs indexed for weeks; 410 says it is finished
  and they drop on the next crawl. A slug that never existed is a different
  case and keeps its redirect home.
  """
  defexception message: "This shop has closed.", plug_status: 410
end

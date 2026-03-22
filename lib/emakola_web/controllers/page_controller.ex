defmodule EmakolaWeb.PageController do
  use EmakolaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

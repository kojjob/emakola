defmodule EmakolaWeb.Auth.ConfirmHTML do
  @moduledoc """
  The confirmation page's markup — the app's own, not the framework's bare
  default. One instruction, one green button, the same language as
  /auth/verify.
  """
  use EmakolaWeb, :html

  embed_templates "auth_confirm_html/*"
end

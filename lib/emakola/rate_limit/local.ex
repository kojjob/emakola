defmodule Emakola.RateLimit.Local do
  @moduledoc false

  use Hammer, backend: :ets
end

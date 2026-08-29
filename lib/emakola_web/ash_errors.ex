defmodule EmakolaWeb.AshErrors do
  @moduledoc """
  Renders Ash/Splode validation errors as user-facing text.

  An Ash error struct carries an *un-interpolated* `:message` template
  (e.g. `"length must be greater than or equal to %{min}"`) alongside a
  `:vars` keyword list holding the substitutions (`[min: 8]`). Reading
  `:message` directly leaks raw `%{...}` placeholders into flash messages,
  so LiveViews that surface Ash errors should go through `message/1`.

  `Exception.message/1` also interpolates, but prepends Splode bread-crumb
  context — useful in logs, noise in a flash. This module returns the
  message alone.
  """

  @doc """
  Returns the error's message with its `vars` interpolated.

      iex> EmakolaWeb.AshErrors.message(%{message: "must be >= %{min}", vars: [min: 8]})
      "must be >= 8"
  """
  def message(%{message: message} = error) when is_binary(message) do
    error
    |> Map.get(:vars, [])
    |> List.wrap()
    |> Enum.reduce(message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", stringify(value))
    end)
  end

  def message(error), do: Exception.message(error)

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value) when is_number(value) or is_atom(value), do: to_string(value)
  defp stringify(value), do: inspect(value)
end

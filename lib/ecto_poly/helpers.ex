defmodule EctoPoly.Helpers do
  @moduledoc false

  @spec dependency_vsn_match?(atom(), binary()) :: boolean()
  def dependency_vsn_match?(dep, req) do
    with :ok <- Application.ensure_loaded(dep),
    vsn when is_list(vsn) <- Application.spec(dep, :vsn) do
      vsn
      |> List.to_string()
      |> Version.match?(req)
    else
      _ -> false
    end
  end
end

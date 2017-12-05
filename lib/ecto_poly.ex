defmodule EctoPoly do
  @moduledoc """
  Creates a polymorphic embedded type
  """

  @doc """
  # Arguments
  
  * `types`: Keyword list of `{name, type}`. The `name` is stored in the database in order to identify what `type` to use in runtime.
  * `type_field`: Name of the field used to the type of that particular object. Default is `:__type__`.

  # Example

      defmodule EctoPoly.TestChannelData do
        use EctoPoly, types: [
          sms: TestSmsChannel,
          email: TestEmailChannel,
        ]
      end
  """
  defmacro __using__(opts) do
    env = __CALLER__

    type_field = 
      opts
      |> Keyword.get(:type_field, :__type__)
      |> Macro.expand(env)
      |> Atom.to_string

    types =
      opts
      |> Keyword.fetch!(:types)
      |> Enum.map(fn {key, value} ->
        {key |> Macro.expand(env), value |> Macro.expand(env)}
      end)
      |> Macro.expand(env)

    union_type = build_union_type(types)

    quote do
      @behaviour Ecto.Type
      @type_field unquote(type_field)

      @type t :: unquote(union_type)

      def type, do: :map

      EctoPoly.__casters__(unquote(types))
      EctoPoly.__dumpers__(unquote(types))
      EctoPoly.__loaders__(unquote(types))

      def load(data) when is_map(data) do
        name =
          data
          |> Map.get(@type_field)
          |> String.to_existing_atom
        
        fields =
          data
          |> Map.delete(@type_field)
          |> Enum.map(fn {key, value} ->
            {String.to_atom(key), value}
          end)

        load(name, fields)
      end

      def cast(_), do: :error
      def dump(_), do: :error
    end
  end

  @doc false
  defmacro __casters__(types) do
    types
    |> Enum.map(&caster/1)
  end

  @doc false
  defmacro __dumpers__(types) do
    types
    |> Enum.map(&dumper/1)
  end

  @doc false
  defmacro __loaders__(types) do
    types
    |> Enum.map(&loader/1)
  end

  defp caster({_, value_type}) do
    quote do
      def cast(value = %unquote(value_type){}), do: {:ok, value}
    end
  end

  defp loader({name, value_type}) do
    loader(is_schema?(value_type), name, value_type)
  end
  defp loader(true, name, value_type) do
    quote do
      defp load(unquote(name), fields) do
        result =
          unquote(value_type)
          |> Ecto.Schema.__unsafe_load__(fields |> Map.new, &Ecto.Type.load/2)

        {:ok, result}
      end
    end
  end
  defp loader(false, name, value_type) do
    quote do
      defp load(unquote(name), fields) do
        result =
          unquote(value_type)
          |> struct!(fields)

        {:ok, result}
      end
    end
  end

  defp dumper({name, value_type}) do
    dumper(is_schema?(value_type), name, value_type)
  end
  defp dumper(true, name, value_type) do
    quote do
      def dump(value = %unquote(value_type){}) do
        fields = unquote(value_type).__schema__(:dump)

        result =
          value
          |> EctoPoly.dump_schema(fields)
          |> Map.put(@type_field, Atom.to_string(unquote(name)))

        {:ok, result}
      end
    end
  end
  defp dumper(false, name, value_type) do
    quote do
      def dump(value = %unquote(value_type){}) do
        result =
          value
          |> Map.from_struct
          |> Map.put(@type_field, Atom.to_string(unquote(name)))

        {:ok, result}
      end
    end
  end

  defp build_union_type(types) do
    types
    |> Enum.reduce(nil, fn (x, acc) ->
      case acc do
        nil ->
          x
        value ->
          {:|, [], [value, x]}
      end
    end)
  end

  defp is_schema?(type) do
    try do
      type.__schema__(:query)
      true
    rescue
      _ in UndefinedFunctionError -> false
    end
  end

  @doc false
  def dump_schema(struct, fields) do
    fields
    |> Enum.reduce(%{}, fn {field, {source, type}}, acc ->
      value = Map.get(struct, field)

      case Ecto.Type.dump(type, value) do
        {:ok, value} ->
          Map.put(acc, source, value)
        :error ->
          raise ArgumentError, "cannot dump `#{inspect value}` as type #{inspect type}"
      end
    end)
  end
end

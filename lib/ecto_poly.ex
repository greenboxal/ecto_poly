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
      |> Atom.to_string()

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
          |> String.to_existing_atom()

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
    value_type
    |> is_schema?
    |> loader(name, value_type)
  end

  defp loader(true, name, value_type) do
    quote do
      defp load(unquote(name), fields) do
        result =
          unquote(value_type)
          |> Ecto.Schema.Loader.unsafe_load(fields |> Map.new(), &EctoPoly.load_value/2)

        {:ok, result}
      end
    end
  end

  defp loader(false, name, value_type) do
    quote do
      defp load(unquote(name), fields) do
        result = unquote(value_type) |> struct!(fields)

        {:ok, result}
      end
    end
  end

  defp dumper({name, value_type}) do
    value_type
    |> is_schema?
    |> dumper(name, value_type)
  end

  defp dumper(true, name, value_type) do
    quote do
      def dump(value = %unquote(value_type){}) do
        embed_type =
          {:embed,
           %Ecto.Embedded{
             cardinality: :one,
             related: unquote(value_type),
             field: :data
           }}

        with {:ok, result} <- Ecto.Type.dump(embed_type, value, &EctoPoly.dump_value/2),
             result = result |> Map.put(@type_field, Atom.to_string(unquote(name))) do
          {:ok, result}
        end
      end
    end
  end

  defp dumper(false, name, value_type) do
    quote do
      def dump(value = %unquote(value_type){}) do
        result =
          value
          |> Map.from_struct()
          |> Map.put(@type_field, Atom.to_string(unquote(name)))

        {:ok, result}
      end
    end
  end

  defp build_union_type(types) do
    types
    |> Enum.reduce(nil, fn x, acc ->
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
  def dump_value(type, value) do
    with {:ok, value} <- Ecto.Type.dump(type, value, &dump_value/2),
         {:ok, value} <- transform_dump(type, value) do
      {:ok, value}
    else
      {:error, error} ->
        {:error, error}

      :error ->
        :error
    end
  end

  @doc false
  def load_value(type, value) do
    with {:ok, value} <- transform_load(type, value),
         {:ok, value} <- Ecto.Type.load(type, value, &load_value/2) do
      {:ok, value}
    else
      {:error, error} ->
        {:error, error}

      :error ->
        :error
    end
  end

  defp transform_dump(type, value), do: do_transform_dump(Ecto.Type.type(type), value)
  defp do_transform_dump(_, nil), do: {:ok, nil}
  defp do_transform_dump(:decimal, value), do: {:ok, Decimal.to_string(value)}

  defp do_transform_dump(:time, %Time{} = t), do: {:ok, t}

  defp do_transform_dump(:time_usec, %Time{} = t), do: {:ok, t}

  defp do_transform_dump(:naive_datetime, %NaiveDateTime{} = dt), do: {:ok, dt}

  defp do_transform_dump(:naive_datetime_usec, %NaiveDateTime{} = dt), do: {:ok, dt}

  defp do_transform_dump(:utc_datetime, %DateTime{} = dt), do: {:ok, dt}

  defp do_transform_dump(:utc_datetime_usec, %DateTime{} = dt), do: {:ok, dt}

  defp do_transform_dump(:date, %Date{} = d), do: {:ok, d}

  defp do_transform_dump(_, value), do: {:ok, value}

  def transform_load(type, value), do: do_transform_load(Ecto.Type.type(type), value)
  defp do_transform_load(_, nil), do: {:ok, nil}
  defp do_transform_load(:decimal, value), do: {:ok, Decimal.new(value)}

  defp do_transform_load(:time, value), do: value |> Time.from_iso8601()

  defp do_transform_load(:time_usec, value), do: value |> Time.from_iso8601()

  defp do_transform_load(:naive_datetime, value), do: value |> NaiveDateTime.from_iso8601()

  defp do_transform_load(:naive_datetime_usec, value), do: value |> NaiveDateTime.from_iso8601()

  defp do_transform_load(:utc_datetime, value) do
    with {:ok, dt, _} <- value |> DateTime.from_iso8601() do
      {:ok, dt}
    end
  end

  defp do_transform_load(:utc_datetime_usec, value) do
    with {:ok, dt, _} <- value |> DateTime.from_iso8601() do
      {:ok, dt}
    end
  end

  defp do_transform_load(:date, value), do: value |> Date.from_iso8601()

  defp do_transform_load(_, value), do: {:ok, value}
end

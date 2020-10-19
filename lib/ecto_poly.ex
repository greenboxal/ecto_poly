defmodule EctoPoly do
  @moduledoc """
  Creates a polymorphic embedded type
  """

  alias Ecto.Changeset

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
      use Ecto.Type

      @type_field unquote(type_field)

      @type t :: unquote(union_type)

      alias Ecto.Changeset

      def type, do: :map

      EctoPoly.__casters__(unquote(types))
      EctoPoly.__dumpers__(unquote(types))
      EctoPoly.__loaders__(unquote(types))

      def __types__, do: unquote(types)

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

  @doc "Casts the given poly with the changeset parameters."
  @spec cast(Changeset.t(), atom, atom) :: Changeset.t()
  @spec cast(Changeset.t(), atom, atom, Keyword.t()) :: Changeset.t()
  def cast(changes, key, typename, opts \\ [])

  def cast(%Changeset{data: data, types: types}, _key, _typename, _opts)
      when data == nil or types == nil do
    raise ArgumentError,
          "cast/2 expects the changeset to be cast. " <>
            "Please call cast/4 before calling cast/2"
  end

  def cast(%Changeset{params: params, types: types} = changeset, key, typename, opts) do
    case types[key] do
      nil ->
        raise ArgumentError, "invalid field: #{key}"

      poly ->
        {key, param_key} = cast_key(key)
        do_cast(changeset, key, params[param_key], poly, typename, opts)
    end
  end

  ## Private.

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
    embedded_structure =
      if __MODULE__.Helpers.dependency_vsn_match?(:ecto, "~> 3.5.0") do
        quote(do: {:parameterized, Ecto.Embedded, var!(struct)})
      else
        quote(do: {:embed, var!(struct)})
      end

    quote do
      def dump(value = %unquote(value_type){}) do
        var!(struct) = %Ecto.Embedded{
          cardinality: :one,
          field: :data,
          related: unquote(value_type),
        }

        embedded_type = unquote(embedded_structure)

        with {:ok, result} <- Ecto.Type.dump(embedded_type, value, &EctoPoly.dump_value/2),
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

  def cast_key(key) when is_atom(key) do
    {key, Atom.to_string(key)}
  end

  defp do_cast(changeset, _, nil, _, _, _), do: changeset

  defp do_cast(changeset, key, param, poly, typename, opts) do
    case poly.cast(param) do
      {:ok, value} ->
        Changeset.put_change(changeset, key, value)

      :error ->
        type =
          poly.__types__
          |> Enum.find(fn
            {^typename, _type} -> true
            {_, ^typename} -> true
            _ -> false
          end)
          |> case do
            nil -> nil
            {_, module} -> module
          end

        do_changeset(changeset, key, param, type, typename, opts)
    end
  end

  defp do_changeset(_changeset, _key, _param, nil, typename, _opts) do
    raise ArgumentError, "invalid type: #{typename}"
  end

  defp do_changeset(changeset, key, param, module, _typename, opts) do
    %Changeset{changes: changes, data: data} = changeset
    on_cast = on_cast_fun(module, opts)
    original = Map.get(data, key)

    struct =
      case original do
        nil -> struct(module)
        _ -> original
      end

    {change, valid?} =
      case on_cast.(struct, param) do
        %Changeset{valid?: false} = change ->
          {change, false}

        change ->
          {Changeset.apply_changes(change), changeset.valid?}
      end

    %{changeset | changes: Map.put(changes, key, change), valid?: valid?}
  end

  defp on_cast_fun(module, opts) do
    opts
    |> Keyword.get(:with)
    |> case do
      nil ->
        on_cast_default(module)

      fun ->
        fun
    end
  end

  defp on_cast_default(module) do
    fn struct, param ->
      try do
        module.changeset(struct, param)
      rescue
        e in UndefinedFunctionError ->
          case System.stacktrace() do
            [{^module, :changeset, args_or_arity, _} | _]
            when args_or_arity == 2
            when length(args_or_arity) == 2 ->
              raise ArgumentError, """
              the module #{inspect(module)} does not define a changeset/2
              function, which is used by EctoPoly.cast/3. You need to
              implement the #{module}.changeset/2 function.
              """

            stacktrace ->
              reraise e, stacktrace
          end
      end
    end
  end
end

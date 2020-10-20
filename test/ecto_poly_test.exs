defmodule EctoPolyTest do
  import Ecto.Query

  use EctoPoly.TestCase

  alias Ecto.Changeset
  alias EctoPoly.{TestRepo, TestSchema, TestEmailChannel, TestSmsChannel, TwilioSmsProvider}

  describe "with simple struct" do
    test "when saving" do
      result =
        %TestSchema{}
        |> TestSchema.changeset(%{
          channel: %TestEmailChannel{email: "foo"}
        })
        |> TestRepo.insert!()

      assert result.channel == %TestEmailChannel{
               email: "foo"
             }
    end

    test "when loading" do
      obj =
        %TestSchema{}
        |> TestSchema.changeset(%{
          channel: %TestEmailChannel{email: "foo"}
        })
        |> TestRepo.insert!()

      result = TestRepo.one(from(o in TestSchema, where: o.id == ^obj.id))

      assert %TestSchema{
               channel: %TestEmailChannel{
                 email: "foo"
               }
             } = result
    end

    test "when querying" do
      value = :rand.uniform() |> Float.to_string()

      %TestSchema{}
      |> TestSchema.changeset(%{
        channel: %TestEmailChannel{email: value}
      })
      |> TestRepo.insert!()

      result =
        TestRepo.one(
          from(o in TestSchema,
            where:
              fragment("?->>'__type__' = ?", o.channel, "email") and
                fragment("?->>'email' = ?", o.channel, ^value)
          )
        )

      assert %TestSchema{
               channel: %TestEmailChannel{
                 email: ^value
               }
             } = result
    end
  end

  describe "with schema" do
    test "when saving and loading" do
      date = DateTime.utc_now() |> DateTime.truncate(:second)

      dates =
        [NaiveDateTime.utc_now(), NaiveDateTime.utc_now()]
        |> Enum.map(&NaiveDateTime.truncate(&1, :second))

      day = Date.utc_today()

      time_by_name = %{
        "lol" => Time.utc_now() |> Time.truncate(:second),
        "wtf" => Time.utc_now() |> Time.truncate(:second)
      }

      result =
        %TestSchema{}
        |> TestSchema.changeset(%{
          channel: %TestSmsChannel{
            number: "+11234567890",
            provider: %TwilioSmsProvider{
              key_id: "id",
              key_secret: "secret",
              date: date,
              dates: dates,
              the_day: day,
              time_by_name: time_by_name,
              price: Decimal.from_float(10.00)
            }
          }
        })
        |> TestRepo.insert!()

      loaded = TestRepo.one(from(o in TestSchema, where: o.id == ^result.id))

      expected = %TestSmsChannel{
        number: "+11234567890",
        provider: %TwilioSmsProvider{
          key_id: "id",
          key_secret: "secret",
          date: date,
          dates: dates,
          the_day: day,
          time_by_name: time_by_name,
          price: Decimal.from_float(10.00)
        }
      }

      assert result.channel == expected
      assert loaded.channel == expected
    end

    test "when querying" do
      value = :rand.uniform() |> Float.to_string()

      %TestSchema{}
      |> TestSchema.changeset(%{
        channel: %TestSmsChannel{
          number: value,
          provider: %TwilioSmsProvider{
            key_id: "id",
            key_secret: "secret"
          }
        }
      })
      |> TestRepo.insert!()

      result =
        TestRepo.one(
          from(o in TestSchema,
            where:
              fragment("?->>'__type__' = ?", o.channel, "sms") and
                fragment("?->>'number' = ?", o.channel, ^value)
          )
        )

      assert %TestSchema{
               channel: %TestSmsChannel{
                 number: ^value,
                 provider: %TwilioSmsProvider{
                   key_id: "id",
                   key_secret: "secret"
                 }
               }
             } = result
    end
  end

  test "with invalid type" do
    changeset =
      %TestSchema{}
      |> TestSchema.changeset(%{
        channel: DateTime.utc_now()
      })

    refute changeset.valid?
    assert [channel: {"is invalid", _}] = changeset.errors
  end

  describe "cast_poly" do
    test "not a poly type" do
      params = %{
        channel: %{
          number: "0123456789"
        }
      }

      assert_raise ArgumentError, "invalid type: unknown", fn ->
        %TestSchema{}
        |> Changeset.cast(params, [])
        |> EctoPoly.cast(:channel, :unknown)
      end
    end

    test "valid by name" do
      number = "0123456789"

      params = %{
        channel: %{
          number: number
        }
      }

      result =
        %TestSchema{}
        |> Changeset.cast(params, [])
        |> EctoPoly.cast(:channel, :sms)
        |> TestRepo.insert!()

      assert match?(%TestSchema{channel: %TestSmsChannel{number: ^number}}, result)
    end

    test "valid by type" do
      number = "0123456789"

      params = %{
        channel: %{
          number: number
        }
      }

      result =
        %TestSchema{}
        |> Changeset.cast(params, [])
        |> EctoPoly.cast(:channel, TestSmsChannel)
        |> TestRepo.insert!()

      assert match?(%TestSchema{channel: %TestSmsChannel{number: ^number}}, result)
    end

    test "invalid changeset" do
      number = "123456789"

      params = %{
        channel: %{
          number: number
        }
      }

      result =
        %TestSchema{}
        |> Changeset.cast(params, [])
        |> EctoPoly.cast(:channel, TestSmsChannel)
        |> TestRepo.insert()

      assert match?(
               {:error,
                %Changeset{
                  changes: %{
                    channel: %Changeset{
                      errors: [number: {"number must start with '0'", []}]
                    }
                  }
                }},
               result
             )
    end
  end
end

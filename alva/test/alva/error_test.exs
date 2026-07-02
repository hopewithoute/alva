defmodule Alva.ErrorTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  test "formats unknown error and logs it" do
    error = %RuntimeError{message: "Something went wrong"}

    log =
      capture_log(fn ->
        assert Alva.Error.format(error) == %{
                 type: "unknown",
                 message: "Internal server error"
               }
      end)

    assert log =~ "Unhandled error: %RuntimeError{message: \"Something went wrong\"}"
  end

  test "formats forbidden error" do
    error = %Ash.Error.Forbidden{}

    assert Alva.Error.format(error) == %{
             type: "forbidden",
             message: "Forbidden"
           }
  end

  test "formats not found error" do
    error = %Ash.Error.Invalid{
      errors: [%Ash.Error.Query.NotFound{}]
    }

    assert Alva.Error.format(error) == %{
             type: "not_found",
             message: "Resource not found"
           }
  end

  test "formats validation error" do
    error = %Ash.Error.Invalid{
      errors: [
        %Ash.Error.Changes.InvalidAttribute{
          field: :name,
          message: "is required"
        }
      ]
    }

    result = Alva.Error.format(error)
    assert result.type == "validation"
    assert Map.has_key?(result.fields, :name)
    assert Enum.any?(result.fields[:name], &String.contains?(&1, "is required"))
  end

  defmodule DummyDomainError do
    defexception [:message, :code, :meta, :field]
  end

  test "formats conflict error when sub error has no field but has code" do
    error = %Ash.Error.Invalid{
      errors: [
        %DummyDomainError{
          message: "Double booked",
          code: "teacher_double_booked"
        }
      ]
    }

    assert Alva.Error.format(error) == %{
             type: "conflict",
             code: "teacher_double_booked",
             message: "Double booked"
           }
  end

  test "formats conflict error with default code when no code provided" do
    error = %Ash.Error.Invalid{
      errors: [
        %DummyDomainError{
          message: "Generic conflict",
          code: nil
        }
      ]
    }

    assert Alva.Error.format(error) == %{
             type: "conflict",
             code: "conflict",
             message: "Generic conflict"
           }
  end
end

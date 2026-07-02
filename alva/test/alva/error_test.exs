defmodule Alva.ErrorTest do
  use ExUnit.Case

  test "formats unknown error" do
    error = %RuntimeError{message: "Something went wrong"}
    
    assert Alva.Error.format(error) == %{
             type: "unknown",
             message: "Something went wrong"
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
end

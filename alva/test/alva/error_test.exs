defmodule Alva.ErrorTest do
  use ExUnit.Case, async: false
  alias Alva.Error

  test "formats not found from Invalid wrapping NotFound" do
    invalid = %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{primary_key: %{id: 1}, resource: User}]}
    assert Error.format(invalid) == %{type: "not_found", message: "Resource not found"}
  end
  
  test "formats direct NotFound" do
    not_found = %Ash.Error.Query.NotFound{primary_key: %{id: 1}, resource: User}
    assert Error.format(not_found) == %{type: "not_found", message: "Resource not found"}
  end

  test "formats conflict error" do
    invalid = %Ash.Error.Invalid{errors: [
      %Ash.Error.Changes.InvalidChanges{message: "Some conflict"}
    ]}
    assert %{type: "conflict", message: "Some conflict"} = Error.format(invalid)
  end

  test "formats validation error with field and bread_crumbs" do
    invalid = %Ash.Error.Invalid{errors: [
      %Ash.Error.Changes.InvalidAttribute{field: :name, message: "is required", bread_crumbs: ["foo"]}
    ]}
    assert %{type: "validation", fields: %{"name" => ["Invalid value provided for name: is required."]}} = Error.format(invalid)
  end
  
  test "formats validation error without breadcrumbs" do
    invalid = %Ash.Error.Invalid{errors: [
      %Ash.Error.Changes.InvalidAttribute{field: :name, message: "is required", bread_crumbs: nil}
    ]}
    assert %{type: "validation", fields: %{"name" => ["Invalid value provided for name: is required."]}} = Error.format(invalid)
  end

  test "formats validation error with path" do
    invalid = %Ash.Error.Invalid{errors: [
      %Ash.Error.Changes.InvalidAttribute{field: :name, path: [:user, :profile], message: "is invalid"}
    ]}
    assert %{type: "validation", fields: %{"user.profile.name" => ["Invalid value provided for name: is invalid."]}} = Error.format(invalid)
  end
  
  test "formats validation error with path ending in field" do
    invalid = %Ash.Error.Invalid{errors: [
      %Ash.Error.Changes.InvalidAttribute{field: :name, path: [:user, :name], message: "is invalid"}
    ]}
    assert %{type: "validation", fields: %{"user.name" => ["Invalid value provided for name: is invalid."]}} = Error.format(invalid)
  end
  
  test "formats validation error without field" do
    invalid = %Ash.Error.Invalid{errors: [
      %Ash.Error.Changes.InvalidChanges{message: "is invalid"}
    ]}
    assert %{type: "conflict", code: "conflict", message: "is invalid"} = Error.format(invalid)
  end

  test "formats forbidden error" do
    forbidden = %Ash.Error.Forbidden{errors: [%Ash.Error.Forbidden.Policy{}]}
    assert %{type: "forbidden", message: "Forbidden Error\n\n* forbidden"} = Error.format(forbidden)
  end

  test "formats unknown error when exposed" do
    old = Application.get_env(:alva, :expose_unknown_errors)
    Application.put_env(:alva, :expose_unknown_errors, true)
    
    assert %{type: "unknown", message: "an error"} = Error.format(%RuntimeError{message: "an error"}, [])
    
    if old, do: Application.put_env(:alva, :expose_unknown_errors, old), else: Application.delete_env(:alva, :expose_unknown_errors)
  end

  test "formats unknown error when not exposed" do
    old = Application.get_env(:alva, :expose_unknown_errors)
    Application.put_env(:alva, :expose_unknown_errors, false)
    
    assert %{type: "unknown", message: "An unexpected error occurred"} = Error.format(%RuntimeError{message: "an error"})
    
    if old, do: Application.put_env(:alva, :expose_unknown_errors, old), else: Application.delete_env(:alva, :expose_unknown_errors)
  end
end

defmodule Alva.Codegen.NamespaceProxyTest do
  use ExUnit.Case
  alias Alva.Codegen.NamespaceProxy

  test "generates a nested interface from flat events" do
    events = ["students.list", "students.create", "teachers.profile.read"]

    result = NamespaceProxy.generate_interface(events)

    assert result =~ "export interface AlvaApi {"
    assert result =~ "students: {"
    assert result =~ "list: (input: AlvaEvents[\"students.list\"][\"input\"]) => Promise<AlvaEvents[\"students.list\"][\"output\"]>;"
    assert result =~ "create: (input: AlvaEvents[\"students.create\"][\"input\"]) => Promise<AlvaEvents[\"students.create\"][\"output\"]>;"
    assert result =~ "teachers: {"
    assert result =~ "profile: {"
    assert result =~ "read: (input: AlvaEvents[\"teachers.profile.read\"][\"input\"]) => Promise<AlvaEvents[\"teachers.profile.read\"][\"output\"]>;"
  end
end

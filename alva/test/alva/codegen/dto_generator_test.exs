defmodule Alva.Codegen.DtoGeneratorTest do
  use ExUnit.Case
  alias Alva.Codegen.DtoGenerator

  defmodule Profile do
    use Ash.Resource, domain: nil
    
    attributes do
      uuid_primary_key :id
      attribute :bio, :string, public?: true
    end
  end

  defmodule User do
    use Ash.Resource, domain: nil
    
    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true, allow_nil?: false
      attribute :age, :integer, public?: true
      attribute :secret, :string, public?: false
    end
    
    relationships do
      belongs_to :profile, Profile, public?: true
    end
  end

  test "generates types.ts content" do
    content = DtoGenerator.generate_types_ts([User, Profile])
    
    # Contains LiveResult
    assert content =~ "export type LiveResult<T>"
    
    # Contains User interface
    assert content =~ "export interface User {"
    assert content =~ "id: string;"
    assert content =~ "name: string;"
    assert content =~ "age?: number;"
    refute content =~ "secret"
    
    # Contains Profile relationship
    assert content =~ "profile?: Profile;"
    
    # Contains Profile interface
    assert content =~ "export interface Profile {"
    assert content =~ "bio?: string;"
  end

  test "generates filter interfaces only for involved resources" do
    events_map = %{
      "users.list" => {User, %{action: :read, enable_filter: true}},
      "profiles.list" => {Profile, %{action: :read, enable_filter: false}}
    }
    content = DtoGenerator.generate_types_ts([User, Profile], events_map)

    # Base filter operator interfaces
    assert content =~ "export interface BaseFieldFilter<T>"
    assert content =~ "export interface StringFieldFilter extends BaseFieldFilter<string>"
    assert content =~ "export interface IntFieldFilter extends BaseFieldFilter<number>"
    assert content =~ "export interface BooleanFieldFilter"

    # UserFilter is generated because enable_filter: true
    assert content =~ "export interface UserFilter {"
    assert content =~ "and?: UserFilter[];"
    assert content =~ "id?: StringFieldFilter | null;"
    assert content =~ "name?: StringFieldFilter | null;"
    assert content =~ "age?: IntFieldFilter | null;"
    assert content =~ "profile?: ProfileFilter | null;"

    # ProfileFilter is generated recursively due to relationship
    assert content =~ "export interface ProfileFilter {"
    assert content =~ "bio?: StringFieldFilter | null;"
  end
end

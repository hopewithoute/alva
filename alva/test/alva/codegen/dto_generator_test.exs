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
end

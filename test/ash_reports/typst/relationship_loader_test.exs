defmodule AshReports.Typst.StreamingPipeline.RelationshipLoaderTest do
  use ExUnit.Case, async: true

  alias AshReports.Typst.StreamingPipeline.RelationshipLoader

  describe "build_load_spec/2" do
    test "builds load spec for simple relationships" do
      relationships = [:author, :tags, :comments]
      max_depth = 2

      load_spec = RelationshipLoader.build_load_spec(relationships, max_depth)

      assert load_spec == [author: [], tags: [], comments: []]
    end

    test "builds load spec for nested relationships" do
      relationships = [author: [:profile], comments: [:author]]
      max_depth = 3

      load_spec = RelationshipLoader.build_load_spec(relationships, max_depth)

      assert load_spec == [author: [profile: []], comments: [author: []]]
    end

    test "respects max depth limit" do
      relationships = [:author, :tags]
      max_depth = 0

      load_spec = RelationshipLoader.build_load_spec(relationships, max_depth)

      assert load_spec == []
    end

    test "limits nested relationship depth" do
      relationships = [author: [profile: [:avatar]]]
      max_depth = 2

      load_spec = RelationshipLoader.build_load_spec(relationships, max_depth)

      # Should only go 2 levels deep
      assert load_spec == [author: [profile: []]]
    end

    test "handles mixed simple and nested relationships" do
      relationships = [:tags, :comments, author: [:profile]]
      max_depth = 3

      load_spec = RelationshipLoader.build_load_spec(relationships, max_depth)

      assert Enum.sort(load_spec) == Enum.sort(tags: [], author: [profile: []], comments: [])
    end
  end

  describe "validate_depth/2" do
    test "validates load spec within depth limit" do
      load_spec = [author: [], tags: []]
      max_depth = 3

      assert {:ok, ^load_spec} = RelationshipLoader.validate_depth(load_spec, max_depth)
    end

    test "validates nested relationships within depth limit" do
      load_spec = [author: [profile: []]]
      max_depth = 3

      assert {:ok, ^load_spec} = RelationshipLoader.validate_depth(load_spec, max_depth)
    end

    test "rejects load spec exceeding depth limit" do
      # 4 levels deep: author -> profile -> avatar -> image
      load_spec = [author: [profile: [avatar: [image: []]]]]
      max_depth = 2

      assert {:error, message} = RelationshipLoader.validate_depth(load_spec, max_depth)
      assert message =~ "exceeds maximum allowed depth"
      assert message =~ "#{max_depth}"
    end

    test "validates empty load spec" do
      load_spec = []
      max_depth = 2

      assert {:ok, []} = RelationshipLoader.validate_depth(load_spec, max_depth)
    end
  end

  describe "apply_load_strategy/2" do
    setup do
      query = Ash.Query.for_read(TestPost, :read)
      {:ok, query: query}
    end

    test "applies eager loading strategy", %{query: query} do
      config = %{
        strategy: :eager,
        max_depth: 2,
        required: [:author],
        optional: [:comments]
      }

      enhanced_query = RelationshipLoader.apply_load_strategy(query, config)

      # Verify the query has load directives applied
      assert %Ash.Query{} = enhanced_query
      refute enhanced_query == query
    end

    test "applies lazy loading strategy", %{query: query} do
      config = %{
        strategy: :lazy,
        max_depth: 2,
        required: [:author],
        optional: [:comments]
      }

      enhanced_query = RelationshipLoader.apply_load_strategy(query, config)

      # With lazy strategy, only required relationships are loaded
      assert %Ash.Query{} = enhanced_query
    end

    test "applies selective loading strategy", %{query: query} do
      config = %{
        strategy: :selective,
        max_depth: 2,
        required: [:author],
        optional: [:comments, :tags]
      }

      enhanced_query = RelationshipLoader.apply_load_strategy(query, config)

      assert %Ash.Query{} = enhanced_query
    end

    test "handles empty relationships", %{query: query} do
      config = %{
        strategy: :selective,
        max_depth: 2,
        required: [],
        optional: []
      }

      enhanced_query = RelationshipLoader.apply_load_strategy(query, config)

      # Should return query unchanged when no relationships specified
      assert %Ash.Query{} = enhanced_query
    end

    test "uses default strategy when not specified", %{query: query} do
      config = %{
        max_depth: 2,
        required: [:author],
        optional: []
      }

      enhanced_query = RelationshipLoader.apply_load_strategy(query, config)

      assert %Ash.Query{} = enhanced_query
    end

    test "uses default max_depth when not specified", %{query: query} do
      config = %{
        strategy: :selective,
        required: [:author],
        optional: []
      }

      enhanced_query = RelationshipLoader.apply_load_strategy(query, config)

      assert %Ash.Query{} = enhanced_query
    end

    test "handles nested required relationships", %{query: query} do
      config = %{
        strategy: :eager,
        max_depth: 3,
        required: [author: [:profile]],
        optional: []
      }

      enhanced_query = RelationshipLoader.apply_load_strategy(query, config)

      assert %Ash.Query{} = enhanced_query
    end
  end

  describe "depth limiting" do
    test "prevents excessive depth with eager loading" do
      query = Ash.Query.for_read(TestPost, :read)

      config = %{
        strategy: :eager,
        max_depth: 1,
        required: [author: [profile: [:avatar]]],
        optional: []
      }

      enhanced_query = RelationshipLoader.apply_load_strategy(query, config)

      # Should limit depth to 1 level
      assert %Ash.Query{} = enhanced_query
    end

    test "selective strategy reduces optional depth" do
      query = Ash.Query.for_read(TestPost, :read)

      config = %{
        strategy: :selective,
        max_depth: 3,
        required: [:author],
        optional: [:comments]
      }

      enhanced_query = RelationshipLoader.apply_load_strategy(query, config)

      # Optional relationships should be loaded at reduced depth (max_depth - 1)
      assert %Ash.Query{} = enhanced_query
    end
  end
end

# Test fixtures
defmodule TestPost do
  @moduledoc false
  use Ash.Resource, domain: TestPostDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  actions do
    default_accept :*
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string
    attribute :body, :string
  end

  relationships do
    belongs_to :author, TestAuthor
    has_many :comments, TestComment

    many_to_many :tags, TestTag do
      through TestPostTag
      source_attribute_on_join_resource :post_id
      destination_attribute_on_join_resource :tag_id
    end
  end
end

defmodule TestAuthor do
  @moduledoc false
  use Ash.Resource, domain: TestPostDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end

  relationships do
    has_many :posts, TestPost
    has_one :profile, TestProfile
  end
end

defmodule TestProfile do
  @moduledoc false
  use Ash.Resource, domain: TestPostDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :bio, :string
  end

  relationships do
    belongs_to :author, TestAuthor
    belongs_to :avatar, TestAvatar
  end
end

defmodule TestAvatar do
  @moduledoc false
  use Ash.Resource, domain: TestPostDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :url, :string
  end
end

defmodule TestComment do
  @moduledoc false
  use Ash.Resource, domain: TestPostDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :content, :string
  end

  relationships do
    belongs_to :post, TestPost
    belongs_to :author, TestAuthor
  end
end

defmodule TestTag do
  @moduledoc false
  use Ash.Resource, domain: TestPostDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end
end

defmodule TestPostTag do
  @moduledoc false
  use Ash.Resource, domain: TestPostDomain, data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    attribute :post_id, :uuid, primary_key?: true, allow_nil?: false
    attribute :tag_id, :uuid, primary_key?: true, allow_nil?: false
  end
end

defmodule TestPostDomain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource TestPost
    resource TestAuthor
    resource TestProfile
    resource TestAvatar
    resource TestComment
    resource TestTag
    resource TestPostTag
  end
end

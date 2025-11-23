require "test_helper"

class RightTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @right_type = right_types(:one)
  end

  test "should get index" do
    get right_types_url
    assert_response :success
  end

  test "should get new" do
    get new_right_type_url
    assert_response :success
  end

  test "should create right_type" do
    assert_difference("RightType.count") do
      post right_types_url, params: { right_type: { group: @right_type.group, name: @right_type.name } }
    end

    assert_redirected_to right_type_url(RightType.last)
  end

  test "should show right_type" do
    get right_type_url(@right_type)
    assert_response :success
  end

  test "should get edit" do
    get edit_right_type_url(@right_type)
    assert_response :success
  end

  test "should update right_type" do
    patch right_type_url(@right_type), params: { right_type: { group: @right_type.group, name: @right_type.name } }
    assert_redirected_to right_type_url(@right_type)
  end

  test "should destroy right_type" do
    assert_difference("RightType.count", -1) do
      delete right_type_url(@right_type)
    end

    assert_redirected_to right_types_url
  end
end

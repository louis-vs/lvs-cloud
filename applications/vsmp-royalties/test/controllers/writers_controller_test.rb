require "test_helper"

class WritersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @writer = writers(:one)
  end

  test "should get index" do
    get writers_url
    assert_response :success
  end

  test "should get new" do
    get new_writer_url
    assert_response :success
  end

  test "should create writer" do
    assert_difference("Writer.count") do
      post writers_url, params: { writer: { first_name: "New", ip_code: "IP999", last_name: "Writer" } }
    end

    assert_redirected_to writer_url(Writer.last)
  end

  test "should show writer" do
    get writer_url(@writer)
    assert_response :success
  end

  test "should get edit" do
    get edit_writer_url(@writer)
    assert_response :success
  end

  test "should update writer" do
    patch writer_url(@writer), params: { writer: { first_name: @writer.first_name, ip_code: @writer.ip_code, last_name: @writer.last_name } }
    assert_redirected_to writer_url(@writer)
  end

  test "should not allow destroying writer" do
    assert_no_difference("Writer.count") do
      delete writer_url(@writer)
    end

    # Should return 404 or routing error since destroy route doesn't exist
    assert_response :not_found
  end
end

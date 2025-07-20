require "test_helper"

class FileUploadsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get file_uploads_new_url
    assert_response :success
  end

  test "should get create" do
    get file_uploads_create_url
    assert_response :success
  end

  test "should get show" do
    get file_uploads_show_url
    assert_response :success
  end

  test "should get index" do
    get file_uploads_index_url
    assert_response :success
  end
end

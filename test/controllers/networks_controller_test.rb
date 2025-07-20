require "test_helper"

class NetworksControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get networks_index_url
    assert_response :success
  end

  test "should get show" do
    get networks_show_url
    assert_response :success
  end

  test "should get map" do
    get networks_map_url
    assert_response :success
  end

  test "should get graph" do
    get networks_graph_url
    assert_response :success
  end

  test "should get analyze" do
    get networks_analyze_url
    assert_response :success
  end
end

require 'test_helper'

class MediaControllerTest < ActionDispatch::IntegrationTest

  test "should get index" do
    get media_index_url
    assert_response :success
  end

  test "should show media" do
    get media_url(@media)
    assert_response :success
  end

end

require "spec_helper"

describe CanvasProxy do

  before do
    @user_id = Settings.canvas_proxy.test_user_id
    Oauth2Data.new_or_update(@user_id, CanvasProxy::APP_ID,
                             Settings.canvas_proxy.test_user_access_token)
    @client = CanvasProxy.new(:user_id => @user_id)
  end

  it "should see an account list as admin" do
    admin_client = CanvasProxy.new(admin: true)
    response = admin_client.request('accounts', '_admin')
    accounts = JSON.parse(response.body)
    accounts.size.should > 0
  end

  it "should see the same account list as admin, initiating CanvasProxy with a passed in token" do
    admin_client = CanvasProxy.new(:access_token => Settings.canvas_proxy.admin_access_token)
    response = admin_client.request('accounts', '_admin')
    accounts = JSON.parse(response.body)
    accounts.size.should > 0
  end

  it "should get own profile as authorized user", :testext => true do
    response = @client.request('users/self/profile', '_admin')
    profile = JSON.parse(response.body)
    profile['login_id'].should == @user_id.to_s
  end

  it "should get courses as known student", :testext => true do
    client = CanvasCoursesProxy.new(:user_id => @user_id)
    response = client.courses
    courses = JSON.parse(response.body)
    courses.size.should > 0
    courses[0]['course_code'].should_not be_nil
  end

  it "should get the coming_up feed for a known user", :testext => true do
    client = CanvasComingUpProxy.new(:user_id => @user_id)
    response = client.coming_up
    tasks = JSON.parse(response.body)
    tasks[0]["type"].should_not be_nil
    tasks[0]["title"].should_not be_nil
  end

  it "should get the todo feed for a known user", :testext => true do
    client = CanvasTodoProxy.new(:user_id => @user_id)
    response = client.todo
    tasks = JSON.parse(response.body)
    tasks[0]["assignment"]["name"].should_not be_nil
    tasks[0]["assignment"]["course_id"].should_not be_nil
  end

  it "should get groups as known member", :testext => true do
    client = CanvasGroupsProxy.new(:user_id => @user_id)
    response = client.groups
    groups = JSON.parse(response.body)
    groups.size.should > 0
    groups[0]['name'].should_not be_nil
  end

  it "should get user activity feed using the Tammi account" do
    # by the time the fake access token is used below, it probably has well expired
    begin
      proxy = CanvasUserActivityProxy.new(:fake => true)
      response = proxy.user_activity
      user_activity = JSON.parse(response.body)
      user_activity.kind_of?(Array).should be_true
      user_activity.size.should == 20
      required_fields = %w(created_at updated_at id type html_url)
      user_activity.each do |entry|
        (entry.keys & required_fields).size.should == required_fields.size
        expect {
          DateTime.parse(entry["created_at"]) unless entry["created_at"].blank?
          DateTime.parse(entry["updated_at"]) unless entry["update_at"].blank?
        }.to_not raise_error
        entry["id"].is_a?(Integer).should == true
        category_specific_id_exists = entry["course_id"] || entry["group_id"] || entry["conversation_id"]
        category_specific_id_exists.blank?.should_not be_true
      end
    ensure
      VCR.eject_cassette
    end
  end

  it "should return nil if server is not available" do
    client = CanvasCoursesProxy.new(user_id: @user_id, fake: false)
    stub_request(:any, /#{Regexp.quote(Settings.canvas_proxy.url_root)}.*/).to_raise(Faraday::Error::ConnectionFailed)
    suppress_rails_logging {
      response = client.courses
      response.should be_nil
    }
    WebMock.reset!
  end

  it "should return nil if server returns error status" do
    client = CanvasCoursesProxy.new(user_id: @user_id, fake: false)
    stub_request(:any, /#{Regexp.quote(Settings.canvas_proxy.url_root)}.*/).to_return(
        status: 503,
        body: '<?xml version="1.0" encoding="ISO-8859-1"?>'
    )
    suppress_rails_logging {
      response = client.courses
      response.should be_nil
    }
    WebMock.reset!
  end

  it "should find a registered user's profile" do
    client = CanvasUserProfileProxy.new(:user_id => @user_id)
    response = client.user_profile
    response.should_not be_nil
  end

  it "should not find an unregistered user's profile" do
    client = CanvasUserProfileProxy.new(:user_id => 'MaynardGKrebs')
    suppress_rails_logging {
      response = client.user_profile
      response.should be_nil
    }
  end

end

class SakaiProxy < BaseProxy
  extend Proxies::EnableForActAs

  APP_ID = "bSpace"

  def initialize(options = {})
    super(Settings.sakai_proxy, options)
  end

  def self.access_granted?(uid)
    settings = Settings.sakai_proxy
    uid && (settings.fake || (settings.host && settings.shared_secret))
  end

  def get_categorized_sites
    url = "#{@settings.host}/sakai-hybrid/sites?categorized=true"
    self.class.fetch_from_cache @uid do
      token = build_token @uid
      Rails.logger.info "SakaiProxy: Fake = #@fake; Making request to #{url} on behalf of user #@uid with x-sakai-token = #{token}, cache expiration #{self.class.expires_in}"
      begin
        response = FakeableProxy.wrap_request(APP_ID, @fake) {
          Faraday::Connection.new(
              :url => url,
              :headers => {
                  'x-sakai-token' => token
              }).get
        }
        if response.status < 400
          Rails.logger.debug "SakaiProxy - Remote server status #{response.status}, Body = #{response.body}"
          return_body = JSON.parse(response.body)
        else
          # Sakai proxy passes error responses back to the client.
          Rails.logger.warn "SakaiProxy connection failed: #{response.status} #{response.body}"
          return_body = response.body
        end
        {
            :body => return_body,
            :status_code => response.status
        }
      rescue Faraday::Error::ConnectionFailed, Faraday::Error::TimeoutError => e
        Rails.logger.warn "SakaiProxy connection failed: #{e.class} #{e.message}"
        {
            :body => "Remote server unreachable",
            :status_code => 503
        }
      end
    end
  end

  private

  def build_token(uid)
    # the x-sakai-token format is defined here:
    # http://www.sakaiproject.org/blogs/lancespeelmon/x-sakai-token-authentication
    data = "#{uid};#{(Time.now.to_f * 1000).to_i.to_s}"
    encoded_data = Base64.encode64("#{OpenSSL::HMAC.digest(
        'sha1',
        @settings.shared_secret,
        data)}").rstrip
    token = "#{encoded_data};#{data}"
  end

end

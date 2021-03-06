class MyBadges::Merged < MyMergedModel

  def initialize(uid, options={})
    super(uid, options)
    @now_time = Time.zone.now
    @enabled_sources = {
      "bcal" => {access_granted: false},
      "bdrive" => {access_granted: GoogleProxy.access_granted?(@uid),
                   source: MyBadges::GoogleDrive.new(@uid),
                   pseudo_enabled: GoogleProxy.allow_pseudo_user?},
      "bmail" => {access_granted: false}
    }
    @service_list = @enabled_sources.keys.to_a
    @enabled_sources.select!{|k,v| v[:access_granted] == true}
  end

  def get_feed_internal
    badges = {}
    @enabled_sources.each do |key, value_hash|
      if (is_acting_as_nonfake_user?) && !value_hash[:pseudo_enabled]
        next
      end
      badges[key] = value_hash[:source].fetch_counts
    end

    #Appending empty counts for non-enabled services
    @service_list.each do |service|
      badges[service] ||= 0
    end

    logger.debug "#{self.class.name} get_feed is #{badges.inspect}"
    {"unread_badge_counts" => badges}
  end

end
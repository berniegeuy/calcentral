class FinalGradesTranslator

  def accept?(event)
    event["code"] == "EndOFTermGrade"
  end

  def translate(notification)
    data = notification.data
    uid = notification.uid
    event = data["event"]
    begin
      timestamp = Time.parse(data["timestamp"]).to_datetime
    rescue
      timestamp = notification.created_at
    end

    Rails.logger.info "#{self.class.name} translating: #{notification}; accept? #{accept?(event)}; timestamp = #{timestamp}; uid = #{uid}"

    return false unless accept?(event) && (payload = event["payload"]) && timestamp && uid

    Rails.logger.debug "#{self.class.name} payload = #{payload}"
    term_cd = FinalGradesEventProcessor.lookup_term_code payload["term"]
    course = CampusData.get_course(payload["ccn"], payload["year"], term_cd)

    return false unless course && course["dept_name"] && course["catalog_id"]

    title = "Final grades posted for #{course["dept_name"]} #{course["catalog_id"]}"
    {
        :id => notification.id,
        :title => title,
        :summary => "Your final grade is available in Bearfacts.",
        :source => event["system"],
        :type => "alert",
        :date => {
            :epoch => timestamp.to_i,
            :datetime => timestamp.rfc3339,
            :date_string => timestamp.strftime("%-m/%d")
        },
        :url => "https://bearfacts.berkeley.edu/bearfacts/",
        :source_url => "https://bearfacts.berkeley.edu/bearfacts/",
        :emitter => "Campus",
        :color_class => "campus-item"
    }
  end

end

require 'nokogiri'
require 'httparty'
require 'csv'

class DiscScraper
  JACKED_ENCODING = {'Tomahawk (八� �钺)' => 'Tomahawk', 'Meteor Hammer (� 星锤)' => 'Meteor Hammer'}

  def initialize; end

  def scrape
    page = HTTParty.get('http://www.inboundsdiscgolf.com/content/?page_id=431')
    parsed_page = Nokogiri::HTML(page)

    parsed_page.css('input').remove
    CSV.open('discs.csv', 'wb') do |csv|
      parsed_page.css('td').select {|td| %w[lp l].include?(td['class']) }.map(&:text).each_slice(3) do |text|
        disc_name = determine_text_name(text[0])
        manufacturer = text[1].force_encoding("UTF-8").scrub("")
        type = text[2].force_encoding("UTF-8").scrub("")
        next if disc_name.blank?

        puts "Disc: #{disc_name}, manufacturer: #{manufacturer}, type: #{type}"
        flight_numbers = flight_number_lookup(manufacturer, disc_name)
        csv << [disc_name, manufacturer, type, flight_numbers]
      end
    end
  end

  def determine_text_name(text)
    return JACKED_ENCODING[text] if JACKED_ENCODING.keys.include?(text)

    text.force_encoding("UTF-8").scrub("")
  rescue ArgumentError
    ''
  end


  def flight_number_lookup(manu, model)
    disc_lookup = [manu, model].map { |text| text.gsub('Prodigy Disc', 'Prodigy').gsub(/\s+/, '-') }.join('-')
    response = HTTParty.get("https://infinitediscs.com/#{disc_lookup}")
    return if response.body.nil? || response.body.empty?

    parsed_page = Nokogiri::HTML(response.body)
    found = parsed_page.css('#ContentPlaceHolder1_lblDiscName').presence
    return '' unless found

    [speed(parsed_page), glide(parsed_page), turn(parsed_page), fade(parsed_page)].join(', ')
  rescue URI::InvalidURIError
    [0,0,0,0]
  end

  def speed(parsed_page)
    parsed_page&.css('#ContentPlaceHolder1_lblSpeed')&.text&.gsub('Speed: ', '')&.to_i
  end

  def glide(parsed_page)
    parsed_page&.css('#ContentPlaceHolder1_lblGlide')&.text&.gsub('Glide: ', '')&.to_i
  end

  def turn(parsed_page)
    parsed_page&.css('#ContentPlaceHolder1_lblTurn')&.text&.gsub('Turn: ', '')&.to_i
  end

  def fade(parsed_page)
    parsed_page&.css('#ContentPlaceHolder1_lblFade')&.text&.gsub('Fade: ', '')&.to_i
  end
end

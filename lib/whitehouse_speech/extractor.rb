require 'rubygems'
require 'bundler/setup'

require 'open-uri'

require 'nokogiri'


module WhitehouseSpeech

  class Extractor
    attr_accessor :content
    attr_reader :filename
    attr_reader :start_time
    attr_reader :end_time
    attr_reader :text

    def initialize(url_or_filename, options)
      @options = options
      @options[:verbose] = false if options[:verbose].nil?

      speech_page = Nokogiri::HTML(open url_or_filename)
      @filename = url_or_filename
      @content = speech_page.css '#content'  # Seems to be in a div with the id=content
      @date = nil
      @text = ""

      _parse_speech_text(@content.css('p'))
    end

    def meta_information
      @content.css('.information').text.strip
    end

    def date
      unless @date
        date_node = @content.css('.information .date')
        unless date_node.empty?
          _parse_date_string(date_node.text.strip)
        end
      end

      @date
    end

    def headlines
      [@content.css('h1').text, @content.css('h3').text]
    end

    def location
      location_tag = @content.css('p.rtecenter')
      location_tag.text if location_tag
    end


    def _parse_date_string(date_string)
      begin
        @date = Date.parse date_string
      rescue ArgumentError
        throw "Invalid date for #{@filename}: '#{date_string}'"
      end
    end

    def _parse_speech_text(contents)
      location_index = contents.find_index do |node|
        node.attribute('class') &&
          node.attribute('class').value =~ /rtecenter/
      end
      location_index = 0 unless location_index
      puts "#{@filename}: No location `.rtecenter' class." if @options[:verbose]

      texts = contents[location_index+1..contents.length].map do |node|
        node.text.strip
      end
      texts = texts.join "\n"

      texts.each_line do |line|
        line.strip!

        if !@office_of
          someones_office = /Office of the (.*)/.match(line)
          @office_of = someones_office[1] if someones_office
        end

        if !date
          # Let's try to find the date since it's likely to be
          # un-marked.
          puts "#{@filename}: No date." if @options[:verbose]
          begin
            _parse_date_string(line)
          rescue StandardError
          end
        elsif date && !start_time
          begin
            #starting_time = DateTime.parse line
            starting_time = DateTime.strptime line, '%l:%M %p %Z'
            @start_time = DateTime.new(date.year,
                                       date.month, date.day,
                                       starting_time.hour,
                                       starting_time.minute, 0,
                                       starting_time.offset)
          rescue ArgumentError
          end
        else
          self.text << line
        end
      end
    end # _parse_speech_text

  end # class Extractor

end # module WhitehouseSpeech

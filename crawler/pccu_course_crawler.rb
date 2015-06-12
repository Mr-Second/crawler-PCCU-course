require 'capybara'
require 'capybara/poltergeist'
require 'pry'
require 'nokogiri'
require 'uri'

class PccuCourseCrawler
  include Capybara::DSL

  def initialize year: current_year, term: current_term, update_progress: nil, after_each: nil, params: nil

    @year = params && params["year"].to_i || year
    @term = params && params["term"].to_i || term
    @update_progress_proc = update_progress
    @after_each_proc = after_each

    @base_url = "https://ap1.pccu.edu.tw"

    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app,  {
        js_errors: false,
        timeout: 300,
        ignore_ssl_errors: true,
        debug: true
      })
    end

    Capybara.javascript_driver = :selenium
    Capybara.current_driver = :selenium
  end

  def courses
    @courses = []

    (1..4).each do |grade|
      visit "https://ap1.pccu.edu.tw/index.asp"
      click_on '課程/課表查詢'

      page.switch_to_window(page.windows.last)

      url = URI.decode current_url
      match = url.match(/ApGUID=\{(?<guid>.+)\}/)
      guid = match[:guid]

      visit URI.encode "https://ap1.pccu.edu.tw/newAp/frame/apMainFrameSet.asp?ApGUID={#{guid}}"

      within_frame 'downFrame' do
        within_frame 'rightFrame' do
          first('#scdfAcadmYear').set(@year-1911)
          first("#scdfTerm option[value=\"#{@term}\"]").select_option
          first("select[name=\"scdfFormClassSect\"] option[value=\"#{grade}\"]").select_option

          click_button '查詢'

          page_count = 1
          begin
            while true
              print " #{page_count} |"
              # File.open("1031/#{grade}-#{page_count}.html", 'w') { |f| f.write(html) }
              parse_course( Nokogiri::HTML(html) )

              click_on '下20筆'

              page_count += 1
            end
          rescue Exception => e
          end
        end
      end
    end

    File.write('courses.json', JSON.pretty_generate(@courses))
    @courses
  end

  def parse_course doc
      doc.css('table.pubTable tr:not(:first-child)').each do |row|
        datas = row.css('td')

        datas[3].search('br').each {|d| d.replace("\n")}
        code_raw = datas[3].text.split("\n")
        code = code_raw[0]
        group = code_raw[1]
        code = "#{@year}-#{@term}-#{code}-#{group}"

        url = datas[5] && datas[5].css('a') && datas[5].css('a')[0] && datas[5].css('a')[0][:href]

        course_days = []
        course_periods = []
        course_locations = []
        datas[8] && datas[8].text.match(/(?<d>\d)\：(?<p>\d{2}\-\d{2})\s+(?<loc>.\s+\d+)/) do |m|
          m[:p] && ps = m[:p].split('-')
          from = ps[0].to_i
          to = ps[1].to_i
          (from..to).each do |period|
            course_days << m[:d].to_i
            course_periods << period.to_i
            course_locations << m[:loc].gsub(/\s+/, ' ')
          end
        end

        dep_raws = datas[1] && datas[1].text.split(' ')
        department = dep_raws[0]
        department_code = dep_raws[1]

        @courses << {
          grade: datas[2] && datas[2].text.to_i,
          code: code,
          department: department,
          department_code: department_code,
          name: datas[5] && datas[5].text.strip.gsub(/\s+/, ' '),
          url: "#{@base_url}#{url}",
          credits: datas[6] && datas[6].text.to_i,
          lecturer: datas[7] && datas[7].text.strip,
          required: datas[9] && datas[9].text.include?('必'),
          day_1: course_days[0],
          day_2: course_days[1],
          day_3: course_days[2],
          day_4: course_days[3],
          day_5: course_days[4],
          day_6: course_days[5],
          day_7: course_days[6],
          day_8: course_days[7],
          day_9: course_days[8],
          period_1: course_periods[0],
          period_2: course_periods[1],
          period_3: course_periods[2],
          period_4: course_periods[3],
          period_5: course_periods[4],
          period_6: course_periods[5],
          period_7: course_periods[6],
          period_8: course_periods[7],
          period_9: course_periods[8],
          location_1: course_locations[0],
          location_2: course_locations[1],
          location_3: course_locations[2],
          location_4: course_locations[3],
          location_5: course_locations[4],
          location_6: course_locations[5],
          location_7: course_locations[6],
          location_8: course_locations[7],
          location_9: course_locations[8],
        }
      end
  end

  def current_year
    (Time.now.month.between?(1, 7) ? Time.now.year - 1 : Time.now.year)
  end

  def current_term
    (Time.now.month.between?(2, 7) ? 2 : 1)
  end
end

cc = PccuCourseCrawler.new(year: 2014, term: 1)
cc.courses

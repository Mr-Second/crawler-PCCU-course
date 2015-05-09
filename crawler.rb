require 'capybara'
require 'capybara/poltergeist'
require 'pry'
require 'nokogiri'
require 'uri'

class Crawler
  include Capybara::DSL

  def initialize
    # Capybara.register_driver :poltergeist_errorless do |app|
    #   Capybara::Poltergeist::Driver.new(app, {
    #     js_errors: true,
    #     inspector: true,
    #     timeout: 10000,
    #     phantomjs_options: ['--load-images=no', '--ignore-ssl-errors=yes', '--ssl-protocol=any'],
    #     cookies: true,
    #   })
    # end
    Capybara.javascript_driver = :selenium
    Capybara.current_driver = :selenium
  end

  def crawl
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
          first('#scdfTerm option[value="1"]').select_option
          first("select[name=\"scdfFormClassSect\"] option[value=\"#{grade}\"]").select_option

          click_button '查詢'
          # save pages

          page_count = 1
          begin
            while true
              doc = Nokogiri::HTML(html)
              File.open("1031/#{grade}-#{page_count}.html", 'w') { |f| f.write(html) }

              click_on '下20筆'
              page_count += 1
            end
          rescue Exception => e

          end
        end
      end
    end
  end

  def parse
    courses = []
    base_url = "https://ap1.pccu.edu.tw"
    Dir.glob('1031/*.html').each do |filename|
      doc = Nokogiri::HTML(File.read(filename))

      doc.css('table.pubTable tr:not(:first-child)').each do |row|
        datas = row.css('td')

        datas[3].search('br').each {|d| d.replace("\n")}
        code_raw = datas[3].text.split("\n")

        url = datas[5] && datas[5].css('a') && datas[5].css('a')[0] && datas[5].css('a')[0][:href]

        periods = []
        m = datas[8] && datas[8].text.match(/(?<d>\d)\：(?<p>\d{2}\-\d{2})\s+(?<loc>.\s+\d+)/)
        if !!m
          m[:p] && ps = m[:p].split('-')
          from = ps[0].to_i
          to = ps[1].to_i
          (from..to).each do |period|
            chars = []
            chars << m[:d]
            chars << period
            chars << m[:loc].gsub(/\s+/, ' ')
            periods << chars.join(',')
          end
        end

        courses << {
          grade: datas[2] && datas[2].text.to_i,
          code: code_raw[0],
          group: code_raw[1],
          name: datas[5] && datas[5].text.strip.gsub(/\s+/, ' '),
          url: "#{base_url}#{url}",
          credits: datas[6] && datas[6].text.to_i,
          lecturer: datas[7] && datas[7].text.strip,
          periods: periods,
          required: datas[9] && datas[9].text,
        }
      end
    end

    File.open('courses.json', 'w') {|f| f.write(JSON.pretty_generate(courses))}
  end
end
crawler = Crawler.new
# crawler.crawl
crawler.parse

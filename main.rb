require 'open-uri'
require 'nokogiri'
require 'restclient'
require 'date'
require 'sqlite3'
require 'pry'

class Database

  def initialize(dbname)
    name = "#{dbname}.db"
    @db = SQLite3::Database.open name
    @table_name = "NumberOnes"
    create_table
  end

  def close
    @db.close
  end

  def create_table
    @db.execute "CREATE TABLE IF NOT EXISTS #{@table_name}(Date TEXT, Title TEXT, Artist TEXT)"
  end

  def add_record(date, title, artist)
    date = add_quotes(date)
    title = add_quotes(title)
    artist = add_quotes(artist)
    str = "INSERT INTO #{@table_name} VALUES(#{date}, #{title}, #{artist})"
    @db.execute str
  end

  def add_quotes(str)
    "\"#{str}\""
  end

end

class Billboard_Page

  BASE_URL = "https://www.billboard.com/charts/hot-100/"
  def initialize(date)
    url = "#{BASE_URL}#{date}"
    begin
      html =open(url, "User-Agent" => "OPERA")
    rescue OpenURI::HTTPError => error
      puts error.io.string
      @status = error.io.string
    else
      @status = "OK"
      @doc = Nokogiri::HTML(html)
      return @doc
    end
  end

  def status
    @status
  end

  def get_title
    ret = @doc.at(get_div(1,"title")).text
    ret.gsub("\"","'")
  end

  def get_artist
    ret = @doc.at(get_div(1,"artist")).text.strip
    ret.gsub("\"","'")
  end

  def get_div(pos, attribute)
    pos_text = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
    pos = pos - 1
    pos = 0 if pos < 0
    pos = pos_text.length if pos > pos_text.length
    return "div[class=\"chart-number-#{pos_text[pos]}__#{attribute}\"]"
  end

end


def get_next_chart_date(last_date)
  (Date.parse(last_date) + DAYS_IN_WEEK).to_s
end

END_DATE = "2019-06-15"
DAYS_IN_WEEK = 7

db_name = "test"
db_name = ARGV[1] if ARGV.length > 1

db = Database.new(db_name)

date =ARGV[0]
if ARGV.length < 1
  puts "Error: starting date must be specified"
  exit(false)
end
begin
  Date.parse(date)
rescue ArgumentError
  puts "Error: #{date} is not a valid date"
  exit(false)
end

while date < END_DATE

  bp = Billboard_Page.new(date)

  if bp.status == "OK"
    title = bp.get_title
    artist = bp.get_artist
    bp = nil
    puts "Number 1 on #{date} was #{title} by #{artist}"
    db.add_record(date,title,artist)
    date = get_next_chart_date(date)
  else
    puts "Error retrieving record for #{date}"
    exit false
  end

  sleep 2
end

db.close
exit(true)

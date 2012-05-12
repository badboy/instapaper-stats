#!/usr/bin/env ruby
# encoding: utf-8

require 'csv'
require 'time'
require 'digest/sha1'
require 'mechanize'
require 'fileutils'

here = File.dirname $0
BACKUP_DIR = File.expand_path(File.join(here, 'backup'))
APP_TMPL = File.join(here, 'html', 'app.mustache')
APP_OUT  = File.join(here, 'html', 'app.js')

def get_instapaper_csv user, password
  agent =  Mechanize.new { |a|
    a.user_agent_alias = 'Linux Firefox'
  }

  start_url = 'http://www.instapaper.com/user/login'

  body = ''
  agent.get(start_url) do |page|
    login_result = page.form_with(action: '/user/login') { |search|
      search.username = user
      search.password = password
    }.submit

    overview_page = login_result.links[0].click

    export_csv = overview_page.form_with(action: '/export/csv')
    if export_csv
      csv_page = export_csv.submit
      body = csv_page.body
    end
  end
  body
end

class Entry
  attr_accessor :url
  attr_accessor :title
  attr_accessor :summary
  attr_accessor :folder

  def initialize url, title, summary, folder
    @url     = url
    @title   = title
    @summary = summary
    @folder  = folder
  end

  def hash
    @hash ||= Digest::SHA1.hexdigest url
  end

  def keys
    [:url, :title, :summary, :folder]
  end
end

def help
  puts <<-EOF
Usage: #{File.basename $0} [method]
  fetch [credentials file]  - Fetch new data and save to 'backup/'.
  info [csv file]           - Show info from csv file.
  search [word]             - Search article by word or url,
                              word can be a regexp.
  csv [dir]                 - Print out latest backup info in CSV format.
  csv_full [dir]            - Print out full backup info in CSV format.
  graph [csv file]          - Write stats data from csv file to 'html/app.js'.
  EOF
end

def fetch
  if ARGV[0].nil? || ARGV[0].empty?
    puts "Error: need credentials file."
    exit 1
  end
  print 'Fetching...'

  user, password = IO.read(ARGV[0]).split('|').map{|e|e.chomp}
  complete_csv = get_instapaper_csv user, password
  t = Time.now.strftime('%Y-%m-%d')
  filename = "instapaper-#{t}.csv"
  FileUtils.mkdir_p BACKUP_DIR
  File.open(File.join(BACKUP_DIR, filename), 'w') { |f|
    f.write complete_csv
  }
  puts "saved to '#{filename}'."

  complete_csv
end

def csv_full dir
  all_folders = ['Unread', 'Archive', 'Starred']
  complete = ["Date,Total,#{all_folders*','}"]

  Dir[File.join(dir, '*')].sort.each do |f|
    total = 0
    folders = {}
    date = f[/(\d{4}-\d{2}-\d{2}).csv/, 1]
    CSV.foreach(f) do |e|
      next if e.first == 'URL'
      ent = Entry.new(*e)
      total += 1

      folders[ent.folder] ||= 0
      folders[ent.folder] += 1
    end
    msg = [date, total]
    all_folders.each do |fo|
      msg << (folders[fo] || 0)
    end
    complete << msg.join(',')
  end

  complete
end

def info csv_file
  entries = 0
  folders = {}
  CSV.foreach(csv_file) do |e|
    next if e.first == 'URL'
    ent = Entry.new(*e)
    entries += 1

    folders[ent.folder] ||= 0
    folders[ent.folder] += 1

  end
  puts "#{entries} items in #{folders.size} folders."
  folders.each do |(f,s)|
    puts "#{f.rjust 7}: #{s.to_s.rjust 3} items"
  end
end

def search word
  reg = /#{word}/i
  seen = []
  Dir["#{BACKUP_DIR}/*"].each do |f|
    if IO.read(f) =~ reg
      CSV.foreach(f) do |e|
        next if e.first == 'URL'
        ent = Entry.new(*e)
        next if seen.include? ent.hash
        if ent.title =~ reg || ent.url =~ reg
          puts "#{ent.title}\n  #{ent.url}"
          seen << ent.hash
        end
      end
    end
  end
end

def csv_full dir
  all_folders = ['Unread', 'Archive', 'Starred']
  complete = ["Date,Total,#{all_folders*','}"]

  Dir[File.join(dir, '*')].sort.each do |f|
    total = 0
    folders = {}
    date = f[/(\d{4}-\d{2}-\d{2}).csv/, 1]
    CSV.foreach(f) do |e|
      next if e.first == 'URL'
      ent = Entry.new(*e)
      total += 1

      folders[ent.folder] ||= 0
      folders[ent.folder] += 1
    end
    msg = [date, total]
    all_folders.each do |fo|
      msg << (folders[fo] || 0)
    end
    complete << msg.join(',')
  end

  complete
end

def csv dir
  all_folders = ['Unread', 'Archive', 'Starred']

  f = Dir[File.join(dir, '*')].sort.last
  total = 0
  folders = {}
  date = f[/(\d{4}-\d{2}-\d{2}).csv/, 1]
  CSV.foreach(f) do |e|
    next if e.first == 'URL'
    ent = Entry.new(*e)
    total += 1

    folders[ent.folder] ||= 0
    folders[ent.folder] += 1
  end
  msg = [date, total]
  all_folders.each do |fo|
    msg << (folders[fo] || 0)
  end
  msg.join(',')
end

def graph file
  data      = {
    'Total'   => [],
    'Unread'  => [],
    'Archive' => [],
    'Starred' => []
  }
  categories = []
  max = 0

  CSV.foreach(file) do |e|
    next if e.first == 'Date'
    categories << e[0].sub(/\d{4}-(\d{2})-(\d{2})/, '"\1/\2"')
    data['Total']   << e[1].to_i
    data['Unread']  << e[2].to_i
    data['Archive'] << e[3].to_i
    data['Starred'] << e[4].to_i
  end
  max = data.map{|(k,v)| v.max }.max + 5

  require 'mustache'

  File.open(APP_OUT, 'w') do |f|
    f.write(Mustache.render(IO.read(APP_TMPL), {
      max:           max,
      categories:    categories.join(','),
      total_data:    data['Total'],
      unread_data:   data['Unread'],
      archive_data:  data['Archive'],
      starred_data:  data['Starred'],
    }))
  end
end

if ['-h', '--help', 'help'].include? ARGV[0]
  help
  exit 1
elsif ARGV.delete 'fetch'
  fetch
elsif ARGV.delete 'info'
  info ARGV[0]
elsif ARGV.delete 'search'
  search ARGV[0]
elsif ARGV.delete 'csv'
  puts csv(ARGV[0])
elsif ARGV.delete 'csv_full'
  puts csv_full(ARGV[0])
elsif ARGV.delete 'graph'
  graph ARGV[0]
else
  help
  exit 1
end

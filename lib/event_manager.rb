require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'



def clean_zipcode(zip)
  zip.to_s.rjust(5, '0')[0, 5]
end

def legislators_from_zip(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
    rescue
      'Find your legislators at www.commoncause.org/take-action/find-elected-officials'
    end
end

def clean_phone_number(phone)
  phone.gsub!(/[^\d]/, '')
  if phone.length < 10
    '0000000000'
  elsif phone.length > 10 && phone[0] != '1'
    '0000000000'
  elsif phone.length > 11
    '0000000000'
  else
    phone
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "./output/thanks_#{id}"
  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def sort_reg_time_by_hour(reg_times)
  reg_times.reduce(Hash.new(0)) do |hash, time|
    hash[time.hour] += 1
    hash
  end.sort_by {|key, val| -val}.to_h
end

def sort_reg_time_by_weekday(reg_times)
  reg_times.reduce(Hash.new(0)) do |hash, time|
    weekdays = ['Sun', 'Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat']
    hash[weekdays[time.wday]] += 1
    hash
  end.sort_by {|key, val| -val}.to_h
end

puts "\nEventManager initialized...\n\n"

content = CSV.open(
  './event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_times = []

content.each do |row|
  id = row[:id]
  name = row[:first_name]
  zip = clean_zipcode(row[:zipcode])
  legislators = legislators_from_zip(zip)
  phone = row[:homephone]
  phone = clean_phone_number(phone)
  reg_time = row[:regdate]
  reg_time = Time.strptime(reg_time, "%D %H:%M")
  reg_times.push(reg_time)

  puts "Creating thank-you letter for #{name}"

  personal_letter = erb_template.result(binding)
  save_thank_you_letter(id, personal_letter)

end

reg_hours = sort_reg_time_by_hour(reg_times)
reg_days = sort_reg_time_by_weekday(reg_times)

puts "Saving peak registration times..."
File.open('registration_hour_data.txt','w') do |file|
  file.puts "Time\tSign ups"
  reg_hours.each {|key, val| file.puts "#{key}:00\t#{val}"}
end
puts "Saving peak registration days..."
File.open('registration_weekday_data.txt','w') do |file|
  file.puts "Day\tSign ups"
  reg_days.each {|key, val| file.puts "#{key}\t#{val}"}
end

puts "Done!"
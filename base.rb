#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'dbpedia'
require 'geocoder'
require 'stemmify'
require 'net/http'


def ps string
  p string
  %x(say "#{string}")
end

class Analyse
  @type
  @known
  attr_accessor :type,:known
  @@types = ["stem","root word of","rootword of","play","tell me who is",'tell me',"tell me about",'do you know',"you know","who's","what's","what's up",'wazzup',"wassup","are you from","are you","where is","where are","when did","whose",'what is','who is','what are','who are','how are','how is','can you','can i','Do you','Have you','Had you','play some music',"play me",'play me music',"play me some music","i want to listen","play my fav track","play my track","lets play some music",'I want to','I really want to','how can it','calculate','define',"tell me about weather","how is the weather today","forecast for today","how is the weather in","weather of","set volume to","set volume at","max volume","decrease volume","decrease the volume","reduce volume","lower the volume","reduce the volume","louder","quieter","mute","unmute","increase the volume","increase volume","raise the volume","decrease volume to","increase volume to",'no music','stop the music',"play next","play last","play previous","stop music","evalute"]

  @@refer_person = ['do you know',"you know","who's",'who is','who are']
  @@refer_mood = ["what's up",'wazzup',"wassup",'how are','how is']
  @@refer_place = ["are you from","where is","where are"]
  @@refer_defination = ["what are","what is","what's",'define',"tell me about","tell me who is"]
  @@ask_for_weather = ["tell me about weather","how is the weather today","forecast for today","how is the weather in","weather of"]
  @@history_related = ["when did","when is"]
  @@volume_control = ["decrease volume to","increase volume to","set volume to","set volume at","unmute","max volume","decrease volume","decrease the volume","reduce volume","lower the volume","reduce the volume","louder","quieter","mute","increase the volume","increase volume","raise the volume"]
  @@music_control = ["play","stop music",'no music','stop the music','play me some music','play some music','play me music',"play me","i want to listen","play my fav track","play my track","lets play some music"]
  @@math = ["calculate","evalute"]
  @@current_playlist = []
  @@current_track_id
  @@play_next = ["play next","play last","play previous"]
  @@root_word = ["stem","root word of","rootword of"]

  def initialize question
    @@types.each do |known_question|

      if question.match(/#{known_question}/i)
        @type = known_question
        @known = true
      end
      if @type.nil?
        @type = question
        @known = false
      end
    end
    prepare_response question,@type
    if @known
      Ruby.talk
    else

    end
  end

  def known?
    @known
  end


  def know_more labels,results,descriptions
    ps "#{labels.join(" Or ")}"
    ps "Which one would you like to know ? or say exit to cancel ?"
    selection = gets.chomp
    if selection == "exit" || selection == "bye"
      ps "Thank you!, would you like to ask more questions"
    else
      labels.each do |l|
        if l.match(/#{selection}/i)
          ps "#{results[labels.find_index(l)+1].description}"
          know_more labels,results,descriptions
        else
          p "no match found"
        end
      end
    end
  end

  def search_dbpedia question,type
    results = Dbpedia.search("#{question.gsub(type,"").strip}",{:max_hits => 6})
    labels = results.collect(&:label)
    description = results.collect(&:description)
    classes = results.collect(&:categories).map{|a| a.collect(&:label)}
    if results.count == 1
      ps "#{description.join(" ")}"
    elsif results.count > 1
      results_with_index = labels.each_with_index.select { |i, idx| i =~ /#{question.gsub(type,"").strip}/i}
      results_with_index.map! { |i| i[1] } # [0,3]
      ps "#{results[results_with_index.first].description}"
      ps " I have found some more results by the same term , Would you like to know them as well"
      yes = gets.chomp
      if yes.strip == "yes" || yes.strip == "affirmative" || yes.strip == "sure" || yes.strip == "yeah" || yes.strip == "why not"
        labels.delete_at(results_with_index.first)
        know_more labels,results,description
      end
    end
  end

  def current_ip_address
    %x(curl ifconfig.me)
  end

  def current_city ip_address
    city = Geocoder.search(ip_address)
    city.first.data["city"]
  end

  def play_music track_name
    unless track_name.empty?
      tracks_found= %x(find ~/Music -type f -iname '*#{track_name}*.mp3')
      tracks = tracks_found.split("\n")
      if tracks.count > 1
        ps "#{tracks.count} tracks found"
        ps "#{tracks.map{|x| ps x.gsub("_"," ").gsub(".mp3","").split("/").last}}"
        @@current_playlist = tracks
        @@current_track_id = 0
        system "afplay '#{tracks.first}' &"
      elsif tracks.count < 1
        ps "Could not find #{track_name} in Music"
      else
        system "afplay '#{tracks.first}' &"
      end
    else

    end
  end

  def prepare_response question,type
    if @@refer_person.include?(type.strip) || @@history_related.include?(type.strip) || @@refer_place.include?(type.strip) || @@refer_defination.include?(type.strip)
        search_dbpedia question,type
    elsif @@root_word.include?(type.strip)
       ps "#{question} is #{question.gsub(type,"").strip}".stem
    elsif @@ask_for_weather.include?(type.strip)
      if type == "how is the weather in" || type == "weather of"
        city = question.gsub(type,"").strip
      end
      ip_address = current_ip_address if city.nil?
      city = current_city ip_address.strip if city.nil?

      uri = URI("http://api.openweathermap.org/data/2.5/weather?q=#{URI::encode(city)}")
      res = JSON.parse(Net::HTTP.get(uri))
      weather_desc = res["weather"].first["description"]
      max_temp = res["main"]["temp_max"].to_i - 273
      min_temp = res["main"]["temp_min"].to_i - 273
      humidity = res["main"]["humidity"]
      ps "The current Weather of #{city}  #{weather_desc} with maximum #{max_temp} degree Celsius and minimum #{min_temp} degree Celsius, Humidity is measured #{humidity} percent"
    elsif @@volume_control.include?(type.strip)
      volume = %x(osascript -e 'get volume settings')
      current_level = volume.split(",").first[/\d+/].to_i
      if type == "decrease volume" || type == "decrease the volume" || type == "reduce volume" || type == "lower the volume" || type == "reduce the volume" || type == "quieter"
        if current_level < 10
          volume = %x(osascript -e 'set volume output muted true')
        else
          volume = %x(osascript -e 'set volume output volume #{current_level - 10}')
        end
      elsif type == "increase the volume" || type == "increase volume" || type == "louder" || type == "raise the volume"
        if current_level > 90
          volume = %x(osascript -e 'set volume output volume 100')
        else
          volume = %x(osascript -e 'set volume output volume #{current_level + 10}')
        end
      elsif type == "mute"
        volume = %x(osascript -e 'set volume output muted true')
      elsif type == "unmute"
        volume = %x(osascript -e 'set volume output muted false')
      elsif type == ("max volume")
        volume = %x(osascript -e 'set volume output volume 100')
      elsif type == "set volume to" || type == "set volume at" || type == "increase volume to" || type == "decrease volume to"
        set_level = question.gsub(type,"").strip[/\d+/].to_i
        volume = %x(osascript -e 'set volume output volume #{set_level}')
      end
    elsif @@music_control.include?(type.strip)
      if type == 'play' || type == 'play me some music' || type == 'play some music' || type == 'play me music' || type == "play me" || type == "i want to listen" || type == "play my fav track" || type == "play my track" || type == "lets play some music"
        track_name = question.gsub(type,"").strip
        play_music track_name
      elsif type == 'no music' || type == 'stop the music' || type == 'stop music'
        %x(killall afplay)
      end
    elsif @@play_next.include?(type.strip)
      if !@@current_playlist.nil?
        if type == "play next"
          if @@current_playlist[@@current_track_id+1]
            %x(killall afplay)
            system "afplay '#{@@current_playlist[@@current_track_id+1]}' &"
            @@current_track_id = @@current_track_id + 1
          else
            %x(killall afplay)
            system "afplay '#{@@current_playlist.first}' &"
            @@current_track_id = 0
          end
        elsif type == "play last"
          %x(killall afplay)
          system "afplay '#{@@current_playlist.last}' &"
          @@current_track_id = @@current_playlist.count - 1
        elsif type == "play previous"
          if @@current_playlist[@@current_track_id - 1]
            %x(killall afplay)
            system "afplay '#{@@current_playlist[@@current_track_id - 1]}' &"
            @@current_track_id = @@current_track_id - 1
          else
            %x(killall afplay)
            system "afplay '#{@@current_playlist.first}' &"
            @@current_track_id = 0
          end
        end
      else
        ps "No songs in the play list"
      end
    elsif @@math.include?(type.strip)
      if question.match(/power/i)
        number1 = question.strip.split("power").first[/\d+/].to_i
        number2 = question.strip.split("power").last[/\d+/].to_i
        answer = number1**number2
        ps answer
      else
        ps "#{eval(question.gsub(type,"").strip)}"
      end
    end
  end

  def register_unkown_question question
    @@types.push(question)
  end
end
class Response
  def initialize response
    if response.class == String
      p response
      %x( say #{response} )
    else
      raise "Response is not correct"
    end
    Ruby.talk
  end
end

class Interact
  @answer
  attr_accessor :answer
  @@greetings = ['hi','hey','hola','hello','helo','namaste']
  def initialize type,question
    if type == question
      if !(@@greetings.select{|i| i.downcase == question.strip.downcase }).empty?
        Response.new((@@greetings.select{|i| i.downcase == question.strip.downcase }).join(" "))
      elsif type.match(/Samantha/i)
        if type.match(/Samantha you are/i)
          adjective = question.downcase.gsub("samantha you are","").strip
          if adjective.match(/ugly/i) || adjective.match(/horrible/i) || adjective.match(/bad/i)
            Response.new("No, You are #{adjective}")
          elsif adjective.match(/beautiful/i) || adjective.match(/gorgeous/i)
            Response.new("Thank you! I am flattered")
          elsif adjective.match(/sexy/i)
            Response.new("Oh really! I... wish I was real")
          end
        elsif type.match(/Samantha fuck you/i)
          Response.new("Oh...! Yeah... Fuck you too!")
        end
      end
    else

    end
  end

end

require 'pry'
#todo Refactor
 class String
   def is_question?
     !(/\?/.match(self).nil?)
   end
 end

class Ruby
  @@mem = {}
  def self.ask
    question = gets.chomp
    analysis = Analyse.new question
    return question,analysis
  end

  def self.talk
    question,analysis = Ruby.ask
    if analysis.known?
      if analysis.type

      end
    else
      Interact.new analysis.type,question
    end
  end

  def initialize
    ps "Hi, I am Samantha and I am a virtual assistant here at Ruby Conference Goa 2015"
    Ruby.talk
  end
  Ruby.new

  #def interact options={}
  #
  #  answer = options[:answer]
  #  if options[:count] == 0
  #    answer = gets.chomp
  #    if answer.is_question?
  #      p "I don't talk to strangers , What is you name ?"
  #      interact options = { :find_answer => find_answer, :count => 0}
  #    else
  #      p "Hi #{extract_proper_noun(answer)}, Nice to meet you!"
  #      analyse(answer)
  #    end
  #  elsif options[:who] || options[:what]
  #    answer = gets.chomp
  #    @@mem[/#{options[:find_answer]}/i] = answer
  #    p "Thanks for Telling"
  #    interact options = { :count => nil}
  #  elsif options[:play]
  #    music = Dir["/Users/arpitkulshrestha/Music/Thomas Jack Presents_ Tropical house Vol.6 with Kygo.mp3"].first
  #    file_name = music.split("/").last
  #    music_dir = music.split("/").shift(music.split("/").size - 1).join("/")
  #    Dir.chdir music_dir
  #    system "afplay '#{file_name}' &"
  #    interact options = {count: 0}
  #  else
  #    question = gets.chomp
  #    analyse(question)
  #  end
  #end
  #
  #
  #
  #def analyse question
  #
  #end

  def extract_proper_noun(question)
    question.match(/[A-Z]{1}[a-z]{2,30}/)
  end
end


#def temp
#  if question == "bye"
#    p "Bye! See you later"
#  elsif question == ""
#    p "What do you want?"
#    interact options = { :count => nil}
#  elsif question.match(/what is/i) || question.match(/what's/i) || question.match(/define/i) || question.match(/whats/i)
#    find_answer = question.gsub(/what is/i,"").gsub(/define/i,"").gsub(/what's/i,"").gsub(/whats/i,"").gsub(" ","")
#    if @@mem.has_key?(/#{find_answer}/i)
#      p @@mem[/#{find_answer}/i]
#      interact options = { :find_answer => find_answer,:count => nil,:what => true }
#    else
#      p "Please Tell me what it is ?"
#      interact options = { :find_answer => find_answer, :what => true }
#    end
#  elsif question.match(/who is/i) || question.match(/who's/i) || question.match(/Do you know/i) || question.match(/you know/i)
#    find_answer = question.gsub(/who is/i,"").gsub(/who's/i,"").gsub(/Do you know/i,"").gsub(/you know/i,"").gsub(" ","")
#
#    if @@mem.has_key?(/#{find_answer}/i)
#      p @@mem[/#{find_answer}/i]
#      interact options = { :find_answer => find_answer,:count => nil,:who => true }
#    else
#      p "Please Tell me who is he/she ?"
#      interact options = { :find_answer => find_answer, :who => true }
#    end
#  elsif question.match(/play/i) || question.match(/i want listen to /i) || question.match(/i want listen/i) || question.match(/can you play/i) || question.match(/please play some music/i)
#    find_answer = question.gsub(/play me/i,"").gsub(/play/i,"").gsub(/i want listen to /i,"").gsub(/i want listen/i,"").gsub(/can you play/i,"").gsub(/please play some music/i,"").gsub(" ","")
#    interact options = { :find_answer => find_answer, :play => true }
#  else
#    if question.is_question?
#      p "Are you asking a question?"
#    end
#    interact options = { :count => nil}
#  end
#end

require 'scraperwiki'
require 'mechanize'
require 'pry-byebug'
require 'json'

all_cards = JSON.parse(File.read('./AllCards.json'))
translations = {}
all_cards.each { |name, card|
  card["foreignData"].each { |data|
    translations[data["name"].downcase] = name.downcase
  }
  translations[name.downcase] = name.downcase
}
puts "Tengo #{translations.length} nombres"

all_cards = nil

agent = Mechanize.new

errors = []

total_price = 0

[
"Bloodstained Mire",
"Wooded foothills",
"polluted delta",
"temple garden",
"stomping ground",
"overgrown tomb"
].each do |card_name|
  card = translations[card_name.downcase]
  puts "No conozco #{card_name}" unless card
  next unless card
  begin
    page = agent.get("http://www.starcitygames.com/results?name=#{card}&auto=Y")
    nms = page.links.find_all { |link| link.text.include? 'NM/M' }
    cheap_edition = nil
    cheap_price = nil
    cheap_name = nil
    nms.each { |nm|
      # binding.pry
      node = nm.node.parent
      while !node.text.start_with?('$') do
        node = node.next_sibling
      end
      price_tag = node.children.first.text
      node = nm.node.parent
      edition = nm.node.parent.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.children[1].children.text
      name_node = nm.node.parent.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling
      version_name = name_node.text.delete("\n").strip
      if version_name.downcase.include? "(not tournament legal)"
        link = name_node.child.child.attr('href')
        puts "Ignoro #{version_name} ( #{link} )"
        next
      end
      if price_tag.start_with?('$')
         price = Float(price_tag[1..-1])
         if !cheap_price || (cheap_price > price)
            cheap_price = price
            cheap_edition = edition
            cheap_name = version_name
         end
      else
          price = "Error! #{price_tag}"
      end
      # puts "#{card}|#{price}"
    }
    puts "#{cheap_name}|#{cheap_price}|#{cheap_edition}"
    total_price += cheap_price if cheap_price
  rescue StandardError => ex
    errors << ex
  end
end

puts "Total: #{total_price}"

unless errors.empty?
  errors.each { |error|
    puts error
    puts error.backtrace
  }
  throw errors.first
end

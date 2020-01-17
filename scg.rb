require 'scraperwiki'
require 'mechanize'
require 'pry-byebug'
require 'json'

begin
  all_cards = JSON.parse(File.read('./AllCards.json'))
rescue
  puts "We're missing an `AllCards.json` file here - download yours from https://mtgjson.com/downloads/compiled/"
  exit 1
end

translations = {}
all_cards.each { |name, card|
  card["foreignData"].each { |data|
    translations[data["name"].downcase] = name.downcase
  }
  translations[name.downcase] = name.downcase
}
puts "|||I have #{translations.length} names"

all_cards = nil

agent = Mechanize.new

errors = []

total_price = 0
card_count = 0

[
"Bloodstained Mire",
"Wooded foothills",
"polluted delta",
"temple garden",
"stomping ground",
"overgrown tomb"
].each do |card_name|
  card = translations[card_name.downcase]
  puts "|||I don't know #{card_name}" unless card
  next unless card
  begin
    cheap_edition = nil
    cheap_price = nil
    cheap_name = nil

    page = agent.get("http://www.starcitygames.com/results?name=#{card}&auto=Y")

    nms = page.links.find_all { |link| link.text.include? 'NM/M' }
    loop do
      nms.each { |nm|
        node = nm.node.parent
        while !node.text.start_with?('$') do
          node = node.next_sibling
        end
        price_tag = node.children.first.text
        node = nm.node.parent
        edition = nm.node.parent.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.children[1].children.text
        name_node = nm.node.parent.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling.previous_sibling
        version_name = name_node.text.delete("\n").strip.gsub('|', '//')
        if version_name.downcase.include? "(not tournament legal)"
          link = name_node.child.child.attr('href')
          puts "|||Ignoring #{version_name} ( #{link} )"
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
      }
      next_page_link = page.links.find { |link| link.text.include? ' - Next>> ' }
      break unless next_page_link
      page = next_page_link.click
      nms = page.links.find_all { |link| link.text.include? 'NM/M' }
    end
    puts "#{cheap_name}|#{cheap_price}|#{cheap_edition}"
    total_price += cheap_price if cheap_price
    card_count += 1 if cheap_price
  rescue StandardError => ex
    errors << ex
  end
end

puts "#{card_count} cards|#{total_price.round(2)}"

unless errors.empty?
  errors.each { |error|
    puts error
    puts error.backtrace
  }
  throw errors.first
end

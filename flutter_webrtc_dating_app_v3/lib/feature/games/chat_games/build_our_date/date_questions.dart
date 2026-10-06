// lib/feature/games/chat_games/build_our_date/date_questions.dart
//
// Build Our Date question pool: 1000 questions, 4 answer options each.
// Both players pick an option in secret; the same pick is a match.
// Ids are stable: never rename or reuse one, only append new questions.

class DateQuestion {
  final String id;
  final String emoji;
  final String prompt;
  final List<String> options;

  const DateQuestion(this.id, this.emoji, this.prompt, this.options);
}

class DateQuestions {
  DateQuestions._();

  static const List<DateQuestion> pool = [
    DateQuestion('spot_first_date', '📍', 'Where should our first date be?',
        ['☕ Cozy café', '🏖️ Beach', '🌳 Park', '🌃 Rooftop']),
    DateQuestion('spot_beach_or_city', '🗺️', 'Beach day or city day?',
        ['🏖️ Beach', '🏙️ City', '🏞️ Lake', '⛰️ Hills']),
    DateQuestion('spot_secret_place', '🤫', 'Pick a hidden-gem spot for us', [
      '📚 Old bookstore',
      '🌿 Secret garden',
      '🎷 Tiny jazz bar',
      '🧁 Corner bakery'
    ]),
    DateQuestion('spot_indoor_outdoor', '🏠', 'Indoor or outdoor date?',
        ['🏠 Indoor', '🌤️ Outdoor', '🔀 A bit of both', '🎲 Surprise me']),
    DateQuestion('spot_rooftop_view', '🌆', 'Best view to share?', [
      '🌅 Sunset rooftop',
      '🌊 Seaside cliff',
      '🌌 Starry hilltop',
      '🏙️ City skyline'
    ]),
    DateQuestion('spot_museum_type', '🏛️', 'Which museum would we wander?', [
      '🦖 Natural history',
      '🖼️ Modern art',
      '🚀 Science center',
      '🏺 Ancient history'
    ]),
    DateQuestion('spot_market', '🛍️', 'Which market should we explore?', [
      '🌮 Night food market',
      '🧺 Farmers market',
      '🪔 Old bazaar',
      '🎨 Flea market'
    ]),
    DateQuestion('spot_garden', '🌷', 'Pick a garden to stroll through', [
      '🌹 Rose garden',
      '🦋 Butterfly park',
      '🎋 Zen garden',
      '🌵 Cactus house'
    ]),
    DateQuestion('spot_waterfront', '🌊', 'Which waterfront spot?', [
      '⛵ Marina',
      '🏝️ Quiet beach',
      '🌉 River promenade',
      '🏞️ Lakeside bench'
    ]),
    DateQuestion('spot_library', '📖', 'A library date would be…', [
      '🤫 Silent reading',
      '📚 Book hunting',
      '☕ Library café',
      '🎧 Audiobook swap'
    ]),
    DateQuestion('spot_aquarium_zoo', '🐠', 'Aquarium, zoo, or something else?',
        ['🐠 Aquarium', '🦒 Zoo', '🐦 Bird sanctuary', '🐢 Rescue center']),
    DateQuestion('spot_amusement', '🎢', 'Amusement park plan?', [
      '🎢 Biggest coaster',
      '🎡 Ferris wheel',
      '🎯 Carnival games',
      '🍭 Snacks only'
    ]),
    DateQuestion(
        'spot_bookstore_cafe', '📚', 'Bookstore café: what do we do?', [
      '📕 Pick books for us',
      '☕ Just sip and chat',
      '✍️ Write tiny notes',
      '🔍 Find the oldest book'
    ]),
    DateQuestion('spot_observatory', '🔭', 'Planetarium or observatory?', [
      '🌌 Planetarium show',
      '🔭 Real telescope',
      '🌠 Meteor watch',
      '🪐 Both, obviously'
    ]),
    DateQuestion('spot_gallery_vibe', '🖼️', 'At an art gallery, we…', [
      '🧐 Act like critics',
      '🎨 Find our favorite',
      '🤳 Pose like statues',
      '🗣️ Invent backstories'
    ]),
    DateQuestion('spot_hidden_cafe', '☕', 'Our café should be…',
        ['🪴 Plant-filled', '📚 Bookish', '🎶 Live acoustic', '🐈 Cat café']),
    DateQuestion('spot_street_walk', '🚶', 'Which street would we wander?', [
      '🏮 Old town lanes',
      '🛍️ Shopping street',
      '🎨 Mural alley',
      '🌳 Tree-lined avenue'
    ]),
    DateQuestion('spot_viewpoint', '🌄', 'Sunrise spot?',
        ['⛰️ Mountain peak', '🏖️ Empty beach', '🏙️ Rooftop', '🛶 On a boat']),
    DateQuestion('spot_picnic', '🧺', "Where's our picnic?", [
      '🌳 Big park',
      '🏞️ By a lake',
      '🌸 Under cherry trees',
      '🏠 Living room floor'
    ]),
    DateQuestion('spot_heritage', '🏰', 'Which heritage spot to explore?',
        ['🏰 Old fort', '🕌 Grand palace', '🗿 Ancient ruins', '🏛️ Stepwell']),
    DateQuestion('spot_arcade', '🕹️', 'At the arcade, we head to…', [
      '🏎️ Racing games',
      '🏀 Hoop shoot',
      '🧸 Claw machine',
      '💃 Dance machine'
    ]),
    DateQuestion('spot_mall', '🏬', 'Mall date: first stop?',
        ['🍦 Food court', '🎬 Cinema', '🎳 Bowling', '👟 Window shopping']),
    DateQuestion('spot_countryside', '🌾', 'Countryside escape?', [
      '🐄 Farm stay',
      '🍓 Berry picking',
      '🌻 Sunflower fields',
      '🏡 Cottage weekend'
    ]),
    DateQuestion('spot_island', '🏝️', 'If we had an island day…', [
      '🤿 Snorkeling',
      '🛶 Kayaking',
      '🐚 Shell hunting',
      '😴 Hammock naps'
    ]),
    DateQuestion('spot_hilltop', '⛰️', 'Hill station vibe?',
        ['🌫️ Misty walks', '🍵 Tea gardens', '🔥 Bonfire', '🏡 Cozy cabin']),
    DateQuestion('spot_desert', '🏜️', 'A desert date would include…', [
      '🐪 Camel ride',
      '🌌 Stargazing',
      '🏕️ Glamping',
      '🎶 Folk music night'
    ]),
    DateQuestion('spot_forest', '🌲', "In a forest, we'd…", [
      '🥾 Hike a trail',
      '🍄 Spot mushrooms',
      '🏕️ Camp overnight',
      '🧘 Just listen'
    ]),
    DateQuestion('spot_lake_activity', '🛶', "At the lake, we'd…",
        ['🛶 Row a boat', '🦆 Feed ducks', '🎣 Try fishing', '🪨 Skip stones']),
    DateQuestion('spot_rooftop_activity', '🌃', "On a rooftop, we'd…", [
      '🍽️ Have dinner',
      '🎬 Watch a movie',
      '🌌 Stargaze',
      '💃 Dance badly'
    ]),
    DateQuestion('spot_cinema_seat', '🎬', 'Best seat in the cinema?',
        ['🎯 Dead center', '🔙 Back row', '🛋️ Recliners', '🌙 Drive-in car']),
    DateQuestion('spot_food_street', '🍢', 'Food street strategy?', [
      '🔁 Share everything',
      '🎯 One stall each',
      '🌶️ Spiciest first',
      '🍨 Dessert first'
    ]),
    DateQuestion('spot_bowling', '🎳', 'At the bowling alley…', [
      '🏆 Play to win',
      '🤪 Silly throws only',
      '🍟 Mostly snacks',
      '🛡️ Bumpers on'
    ]),
    DateQuestion('spot_rainy_place', '🌧️', 'Rainy day spot?',
        ['☕ Café by window', '🎬 Cinema', '🏛️ Museum', '🏠 Blanket fort']),
    DateQuestion('spot_cooking_class', '👩‍🍳', 'Which cooking class?', [
      '🍝 Pasta making',
      '🍣 Sushi rolling',
      '🥟 Dumplings',
      '🍛 Curry from scratch'
    ]),
    DateQuestion('spot_pottery', '🏺', 'Pottery class result?', [
      '🏺 A wonky vase',
      '☕ Matching mugs',
      '🍽️ Tiny plates',
      '🫠 A beautiful mess'
    ]),
    DateQuestion('spot_workshop', '🛠️', 'Pick a hands-on workshop', [
      '🕯️ Candle making',
      '🖌️ Painting',
      '🧵 Embroidery',
      '🌱 Terrarium building'
    ]),
    DateQuestion('spot_temple_of_food', '🍜', 'A famous food spot to try?', [
      '🍛 Biryani joint',
      '🍕 Wood-fire pizza',
      '🍣 Sushi counter',
      '🥞 Dosa corner'
    ]),
    DateQuestion('spot_sports_venue', '🏟️', 'Which live game to watch?',
        ['🏏 Cricket match', '⚽ Football game', '🏀 Basketball', '🎾 Tennis']),
    DateQuestion('spot_concert_venue', '🎤', 'Concert venue?',
        ['🏟️ Big stadium', '🎸 Small club', '🌳 Open-air', '🎻 Concert hall']),
    DateQuestion('spot_theatre', '🎭', 'Theatre night pick?',
        ['🎶 Musical', '😂 Comedy play', '🎭 Drama', '🪄 Magic show']),
    DateQuestion('spot_comedy', '😂', 'Comedy night?',
        ['🎤 Stand-up show', '🎭 Improv', '📺 Sitcom marathon', '🤡 Open mic']),
    DateQuestion('spot_skating', '⛸️', 'Skating date?', [
      '⛸️ Ice skating',
      '🛼 Roller skating',
      '🛹 Skateboarding',
      '🙅 Watch and laugh'
    ]),
    DateQuestion('spot_escape_room', '🔐', 'Escape room theme?', [
      '👻 Haunted house',
      '🏴‍☠️ Pirate ship',
      '🕵️ Detective case',
      '🚀 Space station'
    ]),
    DateQuestion('spot_sanctuary', '🐾', 'Animal date?', [
      '🐶 Shelter volunteering',
      '🐱 Cat café',
      '🐴 Horse farm',
      '🦜 Bird watching'
    ]),
    DateQuestion('spot_bridge', '🌉', 'Walk across a bridge at…',
        ['🌅 Sunrise', '☀️ Noon', '🌇 Sunset', '🌙 Midnight']),
    DateQuestion('spot_fair', '🎪', 'Local fair: first thing?',
        ['🎡 Giant wheel', '🍭 Cotton candy', '🎯 Ring toss', '🎠 Carousel']),
    DateQuestion('spot_hot_spring', '♨️', 'Pick a relaxing getaway', [
      '♨️ Hot springs',
      '💆 Spa day',
      '🧘 Yoga retreat',
      '🛁 Home spa night'
    ]),
    DateQuestion('spot_vineyard_alt', '🍇', 'Countryside tasting?', [
      '🍇 Grape farm tour',
      '🧀 Cheese tasting',
      '🍫 Chocolate factory',
      '🍯 Honey farm'
    ]),
    DateQuestion('spot_mini_golf', '⛳', 'Mini golf rules?', [
      '🏆 Loser buys dessert',
      '🎨 Silly poses per hole',
      '🤝 Team up',
      '🙈 Nobody keeps score'
    ]),
    DateQuestion('spot_trampoline', '🤸', 'Bouncy date?', [
      '🤸 Trampoline park',
      '🏰 Bounce castle',
      '🧗 Climbing wall',
      '🎯 Laser tag'
    ]),
    DateQuestion('food_main_course', '🍽️', 'What are we eating on our date?',
        ['🍕 Pizza', '🍛 Biryani', '🍣 Sushi', '🍔 Burgers']),
    DateQuestion('food_street_snack', '🌮', 'Pick our street snack',
        ['🥟 Momos', '🌮 Tacos', '🥙 Shawarma', '🍢 Pani puri']),
    DateQuestion('food_cuisine_night', '🌏', 'Cuisine for tonight?',
        ['🇮🇳 Indian', '🇮🇹 Italian', '🇯🇵 Japanese', '🇲🇽 Mexican']),
    DateQuestion('food_breakfast', '🥞', 'Breakfast date order?', [
      '🥞 Pancakes',
      '🥘 Poha & chai',
      '🍳 Eggs any style',
      '🥑 Avocado toast'
    ]),
    DateQuestion('food_brunch_vibe', '🥂', 'Brunch vibe?', [
      '🧇 Sweet waffles',
      '🥯 Bagel spread',
      '🍳 Big full plate',
      '🥗 Light & fresh'
    ]),
    DateQuestion('food_lunch_box', '🍱', 'Packing a lunch box for us?',
        ['🥪 Sandwiches', '🍱 Bento', '🥗 Salad bowls', '🍛 Rajma chawal']),
    DateQuestion('food_late_night', '🌙', 'Late-night craving?', [
      '🍜 Instant noodles',
      '🍕 Leftover pizza',
      '🍟 Fries run',
      '🥪 Grilled sandwich'
    ]),
    DateQuestion('food_sharing_style', '🍴', 'How do we order?', [
      '🔁 Share everything',
      '🙅 My plate, my food',
      '🎲 Order for each other',
      "🧑‍🍳 Chef's choice"
    ]),
    DateQuestion('food_spice_level', '🌶️', 'Spice level for our dinner?',
        ['😇 Mild', '🙂 Medium', '🔥 Hot', '🌋 Volcano']),
    DateQuestion('food_pizza_topping', '🍕', 'Our shared pizza topping?',
        ['🍄 Mushroom', '🍍 Pineapple', '🌶️ Paneer tikka', '🧀 Extra cheese']),
    DateQuestion('food_pasta', '🍝', 'Pasta pick?', [
      '🍝 Spaghetti red sauce',
      '🧀 Mac & cheese',
      '🌿 Pesto',
      '🍤 Creamy alfredo'
    ]),
    DateQuestion('food_noodles', '🍜', 'Noodle bowl?',
        ['🍜 Ramen', '🥢 Hakka noodles', '🍲 Pho', '🥡 Pad thai']),
    DateQuestion('food_rice_dish', '🍚', 'Favorite rice dish to share?',
        ['🍛 Biryani', '🥘 Paella', '🍙 Fried rice', '🍚 Khichdi comfort']),
    DateQuestion('food_bread', '🥖', 'Pick a bread',
        ['🫓 Butter naan', '🥖 Baguette', '🥐 Croissant', '🫓 Aloo paratha']),
    DateQuestion('food_curry', '🍛', 'Which curry?', [
      '🧈 Butter chicken',
      '🧀 Paneer makhani',
      '🥥 Thai green curry',
      '🍛 Dal tadka'
    ]),
    DateQuestion('food_dumplings', '🥟', 'Dumpling style?', [
      '🥟 Steamed momos',
      '🔥 Fried momos',
      '🥟 Gyoza',
      '🥟 Dim sum basket'
    ]),
    DateQuestion('food_bbq', '🍖', 'BBQ night must-have?', [
      '🌽 Grilled corn',
      '🍢 Paneer skewers',
      '🍔 Smash burgers',
      '🍍 Grilled pineapple'
    ]),
    DateQuestion('food_salad', '🥗', 'If we had to eat salad…',
        ['🥗 Caesar', '🍉 Watermelon feta', '🥙 Greek', '🫘 Chickpea chaat']),
    DateQuestion('food_soup', '🍲', 'Soup for a cold evening?',
        ['🍅 Tomato soup', '🌽 Sweet corn', '🍜 Manchow', '🍄 Mushroom cream']),
    DateQuestion('food_comfort', '🛋️', 'Ultimate comfort food?', [
      '🍲 Ghar ka dal chawal',
      '🍕 Pizza',
      '🍜 Noodles',
      '🧀 Grilled cheese'
    ]),
    DateQuestion('food_chaat', '🥙', 'Chaat counter pick?',
        ['🥔 Aloo tikki', '🍢 Pani puri', '🥣 Dahi puri', '🍘 Papdi chaat']),
    DateQuestion('food_south_indian', '🥞', 'South Indian plate?',
        ['🥞 Masala dosa', '🍚 Idli sambar', '🍩 Medu vada', '🥞 Uttapam']),
    DateQuestion('food_finger_food', '🍟', 'Finger food platter?',
        ['🍟 Fries', '🧅 Onion rings', '🧆 Falafel', '🍗 Wings or soya bites']),
    DateQuestion('food_sandwich', '🥪', 'Build our sandwich', [
      '🥪 Club',
      '🧀 Grilled cheese',
      '🥒 Bombay masala',
      '🥖 Sub of the day'
    ]),
    DateQuestion('food_fusion', '🧪', "Wildest fusion we'd try?", [
      '🍕 Tandoori pizza',
      '🌮 Butter chicken taco',
      '🍣 Paneer sushi',
      '🍜 Maggi carbonara'
    ]),
    DateQuestion('food_mystery_menu', '🎲', 'Mystery menu: we pick…', [
      '👉 Item #7',
      "🎯 Chef's special",
      '🔀 Random dice roll',
      '👀 Table next to us'
    ]),
    DateQuestion('food_snack_board', '🧀', 'Snack board centerpiece?',
        ['🧀 Cheese', '🍇 Fruits', '🍫 Chocolates', '🥨 Pretzels & dips']),
    DateQuestion(
        'food_cook_together', '👩‍🍳', 'What would we cook together?', [
      '🍝 Pasta from scratch',
      '🍕 Homemade pizza',
      '🥘 One-pot curry',
      '🥞 Pancake stack'
    ]),
    DateQuestion('food_kitchen_roles', '🔪', 'Our kitchen roles?', [
      '🔪 I chop, you cook',
      '🍳 You chop, I cook',
      '🎵 One cooks, one DJs',
      '🧽 Who does dishes?'
    ]),
    DateQuestion('food_chopsticks', '🥢', 'Chopstick skills?', [
      '🥷 Pro level',
      '🤞 Getting there',
      '🍴 Fork please',
      '🤲 Hands are fine'
    ]),
    DateQuestion('food_restaurant_type', '🍷', 'Restaurant vibe?', [
      '🕯️ Candlelit fancy',
      '🏮 Busy street dhaba',
      '🌿 Garden café',
      '🍔 Diner booth'
    ]),
    DateQuestion('food_order_time', '⏳', 'How long do we take to order?', [
      '⚡ 30 seconds',
      '📖 Read whole menu',
      '🙋 Ask the waiter',
      '🔁 Order what they had'
    ]),
    DateQuestion('food_tasting_menu', '🍽️', 'Tasting menu or à la carte?',
        ['🍽️ Tasting menu', '📋 À la carte', '🍱 Thali', '🔁 Buffet']),
    DateQuestion('food_buffet_strategy', '🍛', 'Buffet strategy?', [
      '🥗 Starters only',
      '🍰 Dessert first',
      '🔁 Little of everything',
      '🎯 One favorite, repeat'
    ]),
    DateQuestion('food_thali', '🍛', 'Thali style?',
        ['🌴 South Indian', '🐪 Rajasthani', '🍚 Gujarati', '🐟 Bengali']),
    DateQuestion('food_eat_with_hands', '🙌', 'Eating with our hands?', [
      '🙌 Totally',
      '🍗 Only some dishes',
      '🍴 Cutlery please',
      '🤷 Depends on the food'
    ]),
    DateQuestion('food_mexican', '🌯', 'Mexican night?',
        ['🌮 Tacos', '🌯 Burrito', '🧀 Quesadilla', '🥑 Nachos & guac']),
    DateQuestion('food_japanese', '🍣', 'Japanese menu pick?',
        ['🍣 Sushi', '🍜 Ramen', '🍤 Tempura', '🍛 Katsu curry']),
    DateQuestion('food_chinese', '🥡', 'Indo-Chinese order?', [
      '🥢 Chilli paneer',
      '🍜 Hakka noodles',
      '🥟 Spring rolls',
      '🍚 Manchurian rice'
    ]),
    DateQuestion('food_middle_east', '🧆', 'Middle Eastern platter?',
        ['🧆 Falafel', '🫓 Hummus & pita', '🥙 Shawarma', '🍢 Kebabs']),
    DateQuestion('food_korean', '🍲', 'Korean dinner?',
        ['🍲 Korean BBQ', '🍜 Spicy ramyeon', '🍙 Kimbap', '🍗 Fried chicken']),
    DateQuestion('food_italian', '🇮🇹', 'Italian dinner course?',
        ['🍕 Pizza', '🍝 Pasta', '🍚 Risotto', '🥖 Bruschetta']),
    DateQuestion('food_thai', '🥥', 'Thai food pick?',
        ['🍜 Pad thai', '🥥 Green curry', '🥗 Papaya salad', '🍲 Tom yum']),
    DateQuestion('food_healthy', '🥦', 'Healthy date meal?',
        ['🥗 Buddha bowl', '🍣 Poke bowl', '🍲 Lentil soup', '🌯 Veggie wrap']),
    DateQuestion('food_food_truck', '🚚', 'Food truck pick?', [
      '🌮 Taco truck',
      '🍔 Burger van',
      '🍦 Ice cream truck',
      '🍢 Kebab cart'
    ]),
    DateQuestion('food_picnic_menu', '🧺', 'Picnic basket must?',
        ['🥪 Sandwiches', '🍓 Fresh fruit', '🧁 Cupcakes', '🥟 Samosas']),
    DateQuestion('food_cheese', '🧀', 'Favorite cheese moment?', [
      '🍕 Stretchy pizza pull',
      '🧀 Fondue',
      '🫓 Cheese naan',
      '🥪 Toastie'
    ]),
    DateQuestion('food_potato', '🥔', 'Best form of potato?',
        ['🍟 Fries', '🥔 Aloo paratha', '🥔 Mashed', '🥔 Vada pav']),
    DateQuestion('food_egg_style', '🍳', 'Egg style (or skip)?', [
      '🍳 Sunny side up',
      '🥚 Masala omelette',
      '🍳 Scrambled',
      '🙅 No eggs for me'
    ]),
    DateQuestion('food_paneer', '🧀', 'Paneer dish?', [
      '🍢 Paneer tikka',
      '🧈 Paneer butter masala',
      '🌶️ Chilli paneer',
      '🥬 Palak paneer'
    ]),
    DateQuestion('food_veg_nonveg', '🥬', 'Our dinner menu?',
        ['🥬 All veg', '🍗 Non-veg', '🔀 Mix of both', '🌱 Fully vegan']),
    DateQuestion('food_try_new', '🆕', 'Trying a new dish?', [
      '🙋 Always',
      '🤔 If you try first',
      '🔁 Stick to faves',
      '🎲 Let the waiter pick'
    ]),
    DateQuestion('food_one_meal', '♾️', 'One food forever?',
        ['🍕 Pizza', '🍛 Biryani', '🍜 Noodles', '🥟 Momos']),
    DateQuestion('food_cooking_disaster', '🔥', 'If our cooking fails we…', [
      '📱 Order in',
      '🍜 Instant noodles',
      '🥪 Sandwiches',
      '😂 Eat it anyway'
    ]),
    DateQuestion('food_sauce', '🥫', 'Pick a dip',
        ['🍅 Ketchup', '🌿 Green chutney', '🧄 Garlic mayo', '🌶️ Sriracha']),
    DateQuestion('food_crispy_soft', '😋', 'Crispy or soft?',
        ['🥨 Crispy', '🍞 Soft', '🔀 Both together', "🤷 Whatever's hot"]),
    DateQuestion('food_sweet_savory', '⚖️', 'Sweet or savory person?',
        ['🍬 Sweet', '🧂 Savory', '🌶️ Spicy', '🍋 Tangy']),
    DateQuestion('food_midnight_maggi', '🍜', 'Midnight noodles add-on?',
        ['🧀 Cheese', '🌶️ Extra chilli', '🥚 Egg', '🥬 Veggies']),
    DateQuestion('food_dhaba', '🛣️', 'Highway dhaba order?', [
      '🫓 Parathas & butter',
      '🍛 Dal makhani',
      '🍵 Cutting chai',
      '🥛 Lassi'
    ]),
    DateQuestion('food_wedding_food', '🎊', 'Best wedding-buffet item?', [
      '🥘 Paneer starter',
      '🍮 Gulab jamun',
      '🍛 Biryani',
      '🍨 Live ice cream'
    ]),
    DateQuestion('food_date_dinner_time', '🕖', 'Dinner reservation time?', [
      '🕕 6 PM early bird',
      '🕗 8 PM classic',
      '🕙 10 PM late',
      '🍳 Breakfast instead'
    ]),
    DateQuestion('food_tiffin', '🥡', 'Homemade tiffin for each other?',
        ['🍛 Rajma chawal', '🥪 Sandwich', '🫓 Parathas', '🍝 Leftover pasta']),
    DateQuestion('food_seafood', '🦐', 'Seafood or skip?',
        ['🦐 Prawns', '🐟 Fish curry', '🦑 Calamari', '🙅 Skip it']),
    DateQuestion('food_grill_pick', '🔥', 'Grill or tandoor?',
        ['🔥 Tandoor', '🍖 Grill', '🍳 Pan-fried', '🥘 Slow-cooked']),
    DateQuestion('food_snack_attack', '🍿', 'Movie snack?',
        ['🍿 Popcorn', '🍫 Chocolate', '🍟 Nachos', '🥜 Masala peanuts']),
    DateQuestion('food_food_photo', '📸', 'Before eating, we…', [
      '📸 Photo first',
      '🍴 Dig in',
      '🙏 Moment of thanks',
      '👃 Smell it all'
    ]),
    DateQuestion('food_portion', '🍽️', 'Portion size?', [
      '🥄 Small plates',
      '🍽️ Regular',
      '🐘 Huge platter',
      '🔁 Refill please'
    ]),
    DateQuestion('food_chef_for_day', '👨‍🍳', 'If one of us cooks dinner…', [
      '🍝 Signature dish',
      '📖 New recipe',
      '🍳 Breakfast for dinner',
      '📱 Fancy takeout'
    ]),
    DateQuestion('food_kebab', '🍢', 'Kebab of choice?',
        ['🍢 Seekh', '🧀 Malai tikka', '🥬 Hara bhara', '🍄 Mushroom tikka']),
    DateQuestion('food_pav_bhaji', '🍞', 'Mumbai street classic?',
        ['🍞 Pav bhaji', '🍔 Vada pav', '🥪 Bombay sandwich', '🥘 Misal pav']),
    DateQuestion('food_wraps', '🌯', 'Wrap it up?',
        ['🌯 Kathi roll', '🌯 Burrito', '🥙 Falafel wrap', '🫔 Frankie']),
    DateQuestion('food_bakery_run', '🥐', 'Bakery run pick?', [
      '🥐 Croissant',
      '🥧 Puff pastry',
      '🍞 Garlic bread',
      '🥯 Cinnamon roll'
    ]),
    DateQuestion('food_rainy_snack', '☔', 'Rainy day snack?',
        ['🧅 Onion pakode', '🌽 Roasted bhutta', '🥟 Samosa', '🍜 Hot soup']),
    DateQuestion('food_hotpot', '🍲', 'Hotpot or fondue?',
        ['🍲 Hotpot', '🧀 Cheese fondue', '🍫 Chocolate fondue', '🥘 Sizzler']),
    DateQuestion('food_dine_style', '🪑', 'Dining setup?', [
      '🪑 Fancy table',
      '🧺 Picnic blanket',
      '🛋️ Couch & TV',
      '🚗 Car eats'
    ]),
    DateQuestion('food_eating_speed', '🐢', 'Our eating pace?', [
      '🐢 Slow & chatty',
      '⚡ Fast & hungry',
      '🔀 One fast, one slow',
      '🍽️ Courses with breaks'
    ]),
    DateQuestion('food_leftovers', '📦', 'Leftovers go to…', [
      '📦 Take home',
      '🤝 Split them',
      '🐕 Doggy bag',
      '🧑 Someone in need'
    ]),
    DateQuestion('food_signature', '⭐', 'Our couple signature dish?',
        ['🍕 DIY pizza', '🥘 Biryani', '🍝 Pasta', '🌮 Taco night']),
    DateQuestion('drink_first', '🥤', 'What are we sipping?',
        ['☕ Coffee', '🫖 Masala chai', '🍹 Mocktails', '🧃 Fresh juice']),
    DateQuestion('drink_coffee_order', '☕', 'Our coffee order?',
        ['☕ Cappuccino', '🧊 Iced latte', '🥛 Filter coffee', '🍫 Mocha']),
    DateQuestion('drink_chai_style', '🫖', 'Chai style?', [
      '🫚 Adrak chai',
      '🌿 Elaichi chai',
      '🍵 Kulhad chai',
      '🥛 Extra milky'
    ]),
    DateQuestion('drink_tea_type', '🍵', "Tea that isn't chai?",
        ['🍵 Green tea', '🧋 Bubble tea', '🌼 Chamomile', '🍋 Iced lemon tea']),
    DateQuestion('drink_mocktail', '🍹', 'Pick a mocktail', [
      '🌿 Virgin mojito',
      '🍓 Strawberry fizz',
      '🥭 Mango mule',
      '🍍 Piña colada (virgin)'
    ]),
    DateQuestion('drink_milkshake', '🥤', 'Milkshake flavor?',
        ['🍫 Chocolate', '🍓 Strawberry', '🍌 Banana', '🍪 Oreo']),
    DateQuestion('drink_smoothie', '🍓', 'Smoothie blend?',
        ['🥭 Mango', '🫐 Berry blast', '🥬 Green detox', '🥜 Peanut butter']),
    DateQuestion('drink_cold', '🧊', 'Hot summer cooler?', [
      '🥛 Sweet lassi',
      '🍋 Nimbu pani',
      '🍉 Watermelon juice',
      '🥥 Coconut water'
    ]),
    DateQuestion('drink_soda', '🥤', 'Fizzy pick?',
        ['🥤 Cola', '🍋 Lemon soda', '🍊 Orange soda', '💧 Sparkling water']),
    DateQuestion('drink_hot_choc', '🍫', 'Hot chocolate topping?', [
      '🍡 Marshmallows',
      '🍦 Whipped cream',
      '🌶️ Pinch of chilli',
      '🍪 Cookie dunk'
    ]),
    DateQuestion('drink_coffee_shop', '🏪', 'Coffee shop type?',
        ['🌿 Indie café', '🏢 Big chain', '🛺 Roadside tapri', '🏠 Home brew']),
    DateQuestion('drink_lassi', '🥛', 'Lassi flavor?',
        ['🥛 Sweet', '🧂 Salted', '🥭 Mango', '🌹 Rose']),
    DateQuestion('drink_cheers', '🥂', 'What do we toast with?',
        ['🧃 Juice boxes', '🍹 Mocktails', '☕ Coffee mugs', '🥛 Chai glasses']),
    DateQuestion('drink_sharing', '🥤', 'Share a drink with two straws?', [
      '💕 Yes, cute',
      '🙅 Own drinks',
      '😂 Only for the photo',
      '🤔 Depends on drink'
    ]),
    DateQuestion('drink_boba', '🧋', 'Boba order?',
        ['🧋 Classic milk tea', '🍓 Fruit tea', '🍵 Matcha', '🍫 Brown sugar']),
    DateQuestion('drink_cafe_food', '🥐', 'Coffee and…?',
        ['🥐 Croissant', '🍪 Cookie', '🍰 Cake slice', '🥪 Sandwich']),
    DateQuestion('drink_morning', '🌅', 'Morning drink?',
        ['☕ Coffee', '🫖 Chai', '🍋 Warm lemon water', '🥤 Smoothie']),
    DateQuestion('drink_night', '🌙', 'Night-time drink?',
        ['🥛 Haldi doodh', '🍵 Herbal tea', '🍫 Hot cocoa', '💧 Just water']),
    DateQuestion('drink_juice_bar', '🍊', 'Juice bar pick?',
        ['🍊 Orange', '🥕 Carrot ginger', '🍍 Pineapple', '🥒 Cucumber mint']),
    DateQuestion('drink_kulfi_vs', '🧊', 'Gola or kulfi?',
        ['🍧 Ice gola', '🍦 Kulfi', '🍨 Both', '🥶 Too cold for me']),
    DateQuestion('dessert_first', '🍰', 'Dessert for our date?',
        ['🍫 Brownie', '🍦 Ice cream', '🍮 Gulab jamun', '🍰 Cheesecake']),
    DateQuestion('dessert_ice_cream', '🍦', 'Ice cream flavor?',
        ['🍫 Chocolate', '🍓 Strawberry', '🍦 Vanilla', '🌿 Mint choc chip']),
    DateQuestion('dessert_indian', '🍮', 'Indian sweet?',
        ['🍮 Rasmalai', '🧡 Jalebi', '🍯 Gulab jamun', '🥛 Kheer']),
    DateQuestion('dessert_cake', '🎂', 'Cake flavor?', [
      '🍫 Chocolate truffle',
      '🍓 Red velvet',
      '🍍 Pineapple',
      '☕ Tiramisu'
    ]),
    DateQuestion('dessert_bakery', '🧁', 'Bakery treat?',
        ['🧁 Cupcake', '🍩 Donut', '🥐 Pain au chocolat', '🍪 Cookies']),
    DateQuestion('dessert_share', '🍨', 'One dessert, two spoons?', [
      '🥄 Share it',
      '🍨 One each',
      '🙅 No sharing dessert',
      '🔁 Order three'
    ]),
    DateQuestion('dessert_frozen', '🍧', 'Frozen treat?',
        ['🍦 Gelato', '🍧 Frozen yogurt', '🍦 Kulfi', '🍨 Sundae']),
    DateQuestion('dessert_chocolate', '🍫', 'Chocolate type?',
        ['🍫 Dark', '🥛 Milk', '🤍 White', '🥜 With nuts']),
    DateQuestion('dessert_waffle', '🧇', 'Waffle topping?',
        ['🍫 Nutella', '🍓 Berries', '🍯 Maple syrup', '🍌 Banana & honey']),
    DateQuestion('dessert_pancake', '🥞', 'Pancake stack style?',
        ['🍯 Classic syrup', '🍫 Choco chips', '🫐 Blueberry', '🍌 Banana']),
    DateQuestion('dessert_pie', '🥧', 'Pick a pie',
        ['🍎 Apple', '🍋 Lemon', '🍒 Cherry', '🎃 Pumpkin']),
    DateQuestion('dessert_mithai_box', '🎁', 'Mithai box must-have?',
        ['🟨 Kaju katli', '🟠 Motichoor laddoo', '🟤 Barfi', '🍬 Peda']),
    DateQuestion('dessert_fondue', '🍫', 'Chocolate fondue dippers?',
        ['🍓 Strawberries', '🍡 Marshmallows', '🍌 Bananas', '🥨 Pretzels']),
    DateQuestion('dessert_halwa', '🥕', 'Halwa pick?', [
      '🥕 Gajar halwa',
      '🌾 Sooji halwa',
      '🫘 Moong dal halwa',
      '🎃 Pumpkin halwa'
    ]),
    DateQuestion('dessert_late', '🌙', 'Dessert run at midnight?', [
      '🍦 Ice cream parlour',
      '🍩 Donut shop',
      '🍪 Bake cookies',
      '🙅 Sleep instead'
    ]),
    DateQuestion('dessert_baking', '🧑‍🍳', 'Bake together?',
        ['🍪 Cookies', '🧁 Cupcakes', '🍞 Banana bread', '🍰 Mug cake']),
    DateQuestion('dessert_topping', '🍬', 'Best topping?',
        ['🌈 Sprinkles', '🍫 Choco sauce', '🍯 Caramel', '🥜 Crushed nuts']),
    DateQuestion('dessert_fruit', '🍓', 'Fruit dessert?', [
      '🍓 Strawberries & cream',
      '🥭 Mango slices',
      '🍉 Fruit salad',
      '🍎 Baked apple'
    ]),
    DateQuestion('dessert_crepe', '🥞', 'Crepe filling?',
        ['🍫 Nutella', '🍌 Banana', '🍓 Strawberry', '🧀 Cream cheese']),
    DateQuestion('dessert_macaron', '🌈', 'Macaron color to pick?',
        ['🌸 Pink rose', '🍫 Brown choc', '💛 Lemon yellow', '💚 Pistachio']),
    DateQuestion('dessert_kulfi', '🍦', 'Kulfi flavor?',
        ['🥜 Pista', '🥭 Mango', '🌹 Rose', '🍮 Malai']),
    DateQuestion('dessert_sundae', '🍨', 'Build-a-sundae base?',
        ['🍦 Vanilla', '🍫 Chocolate', '🍓 Strawberry', '☕ Coffee']),
    DateQuestion('dessert_birthday', '🎂', 'Surprise birthday cake theme?', [
      '🍫 Classic chocolate',
      '🎨 Photo cake',
      '🌈 Rainbow layers',
      '🧁 Cupcake tower'
    ]),
    DateQuestion('dessert_after_dinner', '🍬', 'After dinner?',
        ['🌿 Saunf mix', '🍬 Mint', '🍫 Chocolate square', '🍃 Paan']),
    DateQuestion('dessert_cookie', '🍪', 'Cookie texture?',
        ['🫓 Crispy', '🧸 Chewy', '🔥 Warm & gooey', '🥛 Dunked in milk']),
    DateQuestion('dessert_rainy', '🌧️', 'Rainy day sweet?',
        ['🍫 Hot brownie', '🥞 Malpua', '🍩 Donuts', '🍮 Warm kheer']),
    DateQuestion('dessert_healthy', '🍎', 'Healthy-ish dessert?', [
      '🍌 Frozen banana bites',
      '🥣 Yogurt parfait',
      '🍫 Dark choc square',
      '🍇 Frozen grapes'
    ]),
    DateQuestion('dessert_cotton', '🍭', 'Fair-ground sweet?', [
      '🍭 Cotton candy',
      '🍎 Candy apple',
      '🍿 Caramel popcorn',
      '🍩 Mini donuts'
    ]),
    DateQuestion('dessert_ultimate', '👑', 'Ultimate dessert battle?',
        ['🍫 Brownie', '🍮 Gulab jamun', '🍰 Cheesecake', '🍦 Gelato']),
    DateQuestion('act_main', '🎯', 'What do we do on our date?',
        ['🎬 Movie', '🎳 Bowling', '🚶 Long walk', '🎤 Karaoke']),
    DateQuestion('act_chill_or_active', '⚡', 'Chill date or active date?',
        ['😌 Chill', '🏃 Active', '🔀 Half and half', '🎲 Coin toss']),
    DateQuestion('act_board_game', '🎲', 'Board game night pick?',
        ['🎲 Ludo', '🏠 Monopoly', '♟️ Chess', '🔤 Scrabble']),
    DateQuestion('act_card_game', '🃏', 'Card game?',
        ['🃏 UNO', '♠️ Rummy', '🐟 Go Fish', '🃏 Snap']),
    DateQuestion('act_video_game', '🎮', 'Video game together?',
        ['🍄 Mario Kart', '⚽ FIFA', '🌾 Stardew Valley', '🔫 Co-op shooter']),
    DateQuestion('act_puzzle', '🧩', 'Puzzle time?', [
      '🧩 1000-piece jigsaw',
      '📰 Crossword',
      '🔢 Sudoku race',
      '🧠 Riddles'
    ]),
    DateQuestion('act_creative', '🎨', 'Creative date?', [
      '🎨 Paint each other',
      '📸 Photo walk',
      '✍️ Write a poem',
      '🎶 Make a song'
    ]),
    DateQuestion('act_dance_class', '💃', 'Dance class style?',
        ['💃 Salsa', '🪩 Bollywood', '🕺 Hip-hop', '🩰 Ballroom']),
    DateQuestion('act_karaoke_song', '🎤', 'Our karaoke duet genre?', [
      '🎶 Bollywood classic',
      '🎸 Rock anthem',
      '💿 2000s pop',
      '🎵 Cheesy love song'
    ]),
    DateQuestion('act_sport_together', '⚽', 'Play a sport together?',
        ['🏸 Badminton', '🎾 Tennis', '🏏 Gully cricket', '🏀 Basketball']),
    DateQuestion('act_water', '🌊', 'Water activity?',
        ['🏊 Swimming', '🛶 Kayaking', '🏄 Surfing lesson', '🚤 Boat ride']),
    DateQuestion('act_adventure', '🪂', 'Adventure activity?', [
      '🪂 Paragliding',
      '🧗 Rock climbing',
      '🚣 River rafting',
      '🪢 Zipline'
    ]),
    DateQuestion('act_walk_type', '🚶', 'What kind of walk?', [
      '🌳 Park loop',
      '🏙️ City night walk',
      '🏖️ Beach walk',
      '🥾 Trail hike'
    ]),
    DateQuestion('act_photo_walk', '📸', 'Photo walk theme?', [
      '🌸 Flowers',
      '🏛️ Old buildings',
      '🐕 Street dogs',
      '🌅 Golden hour'
    ]),
    DateQuestion('act_stargazing', '🌌', 'Stargazing plan?',
        ['🔭 Telescope', '🛌 Blanket on grass', '🚗 Car roof', '📱 Star app']),
    DateQuestion('act_volunteer', '🤝', 'Volunteer together?', [
      '🐶 Animal shelter',
      '🌳 Tree planting',
      '📚 Teach kids',
      '🍲 Community kitchen'
    ]),
    DateQuestion('act_gardening', '🌱', 'Gardening date?', [
      '🌻 Plant flowers',
      '🌿 Herb garden',
      '🍅 Grow veggies',
      '🪴 Repot houseplants'
    ]),
    DateQuestion('act_diy', '🛠️', 'DIY project?', [
      '🪑 Build furniture',
      '🖼️ Make a photo wall',
      '🕯️ Make candles',
      '🧶 Knit scarves'
    ]),
    DateQuestion('act_learn_together', '🧠', 'Learn something new together?', [
      '🗣️ A new language',
      '🎸 An instrument',
      '💻 Coding',
      '🍳 A cuisine'
    ]),
    DateQuestion('act_trivia', '❓', 'Trivia night category?',
        ['🎬 Movies', '🌍 Geography', '🎵 Music', '🏏 Sports']),
    DateQuestion('act_spa', '💆', 'Home spa night?', [
      '🧖 Face masks',
      '💅 Paint nails',
      '🛁 Bubble bath',
      '💆 Massage swap'
    ]),
    DateQuestion('act_yoga', '🧘', 'Yoga date?', [
      '🧘 Couples yoga',
      '🌅 Sunrise session',
      '😂 Laughing yoga',
      '🐐 Goat yoga'
    ]),
    DateQuestion('act_run', '🏃', 'Running date?', [
      '🌅 Morning jog',
      '🏅 Fun 5K',
      '🐢 Walk-jog combo',
      '🙅 Cheer from café'
    ]),
    DateQuestion('act_cycle', '🚲', 'Cycling plan?', [
      '🌳 Park loop',
      '🏙️ City ride',
      '🛤️ Countryside trail',
      '🚲 Tandem bike'
    ]),
    DateQuestion('act_gym', '🏋️', 'Gym date?', [
      '🏋️ Lift together',
      '🥊 Boxing class',
      '🧗 Bouldering',
      '🙅 Skip, eat instead'
    ]),
    DateQuestion('act_sleepover_fort', '🏰', 'Blanket fort activity?',
        ['🎬 Movie marathon', '📖 Read aloud', '🔦 Ghost stories', '🎲 Games']),
    DateQuestion('act_scavenger', '🗺️', 'Scavenger hunt prize?', [
      '🍦 Ice cream',
      '🏆 Bragging rights',
      '🎁 Small gift',
      '📸 Winner picks photo'
    ]),
    DateQuestion('act_drawing', '✏️', 'Drawing challenge?', [
      '🖼️ Draw each other',
      '🙈 Blind portraits',
      '🐾 Draw our pets',
      '🏠 Dream house'
    ]),
    DateQuestion('act_baking_off', '🍪', 'Bake-off judge?',
        ['👵 A family member', '🐶 Our pet', '😋 Ourselves', '📱 Online poll']),
    DateQuestion('act_movie_marathon', '🍿', 'Movie marathon theme?', [
      '🦸 Superheroes',
      '🎞️ Old classics',
      '🧙 Fantasy',
      '🇮🇳 Bollywood hits'
    ]),
    DateQuestion('act_music_jam', '🎸', 'Music jam?', [
      '🎸 Guitar & singing',
      '🥁 Pots and pans',
      '🎹 Keyboard duet',
      '📱 Make beats on phone'
    ]),
    DateQuestion('act_writing', '✍️', 'Writing date?', [
      '💌 Letters to future us',
      '📜 Short story together',
      '🎤 Funny rap',
      '📝 Bucket list'
    ]),
    DateQuestion('act_bucket_list', '📝', 'Top bucket-list item together?', [
      '✈️ See the world',
      '🌌 Northern lights',
      '🤿 Scuba dive',
      '🏕️ Desert camping'
    ]),
    DateQuestion('act_vlog', '🎥', 'Make a vlog about…',
        ['🍜 Food crawl', '🗺️ Day trip', '🏠 Room tour', "🐾 Pet's day"]),
    DateQuestion('act_talent_show', '🌟', 'Private talent show act?',
        ['🎤 Singing', '🪄 Magic trick', '😂 Impressions', '💃 Dance']),
    DateQuestion('act_thrift', '👕', 'Thrift challenge?', [
      '🤡 Funniest outfit',
      '✨ Best budget look',
      '🎩 Retro theme',
      '🎁 Gift for each other'
    ]),
    DateQuestion('act_quiz_each_other', '❔', 'Quiz each other on…',
        ['🎂 Childhood', '🎵 Fave songs', '🍕 Food orders', '🎬 Movie quotes']),
    DateQuestion('act_cooking_challenge', '🧑‍🍳', 'Cooking challenge?', [
      '🥫 Mystery ingredient',
      '⏱️ 15-minute meal',
      '💸 Under ₹200 / \$5',
      '🍳 Only one pan'
    ]),
    DateQuestion('act_game_show', '📺', 'Our date as a game show?', [
      '💰 Quiz show',
      '🏃 Obstacle course',
      '🎤 Singing battle',
      '🧩 Puzzle race'
    ]),
    DateQuestion('act_charades', '🎭', 'Charades category?',
        ['🎬 Movies', '🐘 Animals', '🎵 Songs', '👨‍🍳 Jobs']),
    DateQuestion('act_kite', '🪁', 'Kite flying?', [
      '🪁 Kite battle',
      '🌈 Biggest kite',
      '🌬️ Just float it',
      '🙅 Watch others'
    ]),
    DateQuestion('act_fishing_alt', '🎣', 'Slow outdoor hobby?', [
      '🎣 Fishing',
      '🐦 Birdwatching',
      '🪨 Rock skipping',
      '🌄 Sketching scenery'
    ]),
    DateQuestion('act_rainy_activity', '☔', 'Rainy day activity?', [
      '💃 Dance in rain',
      '🧅 Pakode & chai',
      '🎬 Movie',
      '📖 Read together'
    ]),
    DateQuestion('act_sunny_activity', '☀️', 'Sunny day activity?',
        ['🏖️ Beach', '🧺 Picnic', '🚲 Bike ride', '🍦 Ice cream crawl']),
    DateQuestion('act_snow_activity', '❄️', 'Snow day activity?', [
      '☃️ Build a snowman',
      '🛷 Sledding',
      '⛷️ Skiing',
      '☕ Cocoa by fireplace'
    ]),
    DateQuestion('act_night_activity', '🌙', 'Late-night plan?', [
      '🌌 Stargazing',
      '🚗 Drive & music',
      '🍜 Midnight food run',
      '🎮 Game till dawn'
    ]),
    DateQuestion('act_morning_activity', '🌅', 'Early morning plan?',
        ['🌄 Sunrise hike', '🥞 Breakfast café', '🧘 Yoga', '🏃 Jog']),
    DateQuestion('act_competitive', '🏆', 'How competitive are we?',
        ['🏆 Must win', '😄 Just for fun', '🤝 Team only', '🙈 I let you win']),
    DateQuestion('act_lazy', '🛋️', 'Lazy day together?', [
      '📺 Binge a series',
      '😴 Nap marathon',
      '🍕 Order everything',
      '📚 Read side by side'
    ]),
    DateQuestion('act_live_show', '🎟️', 'Live show tickets?',
        ['🎤 Concert', '😂 Stand-up', '🎭 Play', '🎪 Circus']),
    DateQuestion('act_language', '🗣️', 'Learn to say "hi" in…',
        ['🇯🇵 Japanese', '🇫🇷 French', '🇪🇸 Spanish', '🇰🇷 Korean']),
    DateQuestion('act_book_club', '📚', 'Two-person book club?',
        ['🔍 Mystery', '💕 Romance', '🚀 Sci-fi', '🧠 Self-help']),
    DateQuestion('act_podcast', '🎧', 'Start a podcast about…', [
      '🍜 Food reviews',
      '🎬 Movie rants',
      '💬 Dating stories',
      '👽 Conspiracy fun'
    ]),
    DateQuestion('act_crafts', '✂️', 'Craft night?', [
      '📒 Scrapbook',
      '🎨 Rock painting',
      '📿 Bracelet making',
      '🧶 Crochet'
    ]),
    DateQuestion('act_magic', '🪄', 'Learn a magic trick?', [
      '🃏 Card trick',
      '🪙 Coin vanish',
      '🧠 Mind reading',
      '🐇 Pull a bunny'
    ]),
    DateQuestion('act_dance_home', '🕺', 'Kitchen dance party song?',
        ['🪩 Disco', '🎶 Bollywood item song', '💃 Salsa', '🎵 Slow song']),
    DateQuestion('act_road_game', '🚗', 'Road trip game?',
        ['🎵 Antakshari', '🔤 I spy', '🚙 Car color bingo', '❓ 20 questions']),
    DateQuestion('act_photo_booth', '📷', 'Photo booth pose?', [
      '😜 Silly faces',
      '😎 Cool and serious',
      '🤗 Big hug',
      '🎭 Props everywhere'
    ]),
    DateQuestion('act_tour', '🧭', 'Guided tour type?', [
      '👻 Ghost walk',
      '🍜 Food tour',
      '🏛️ History tour',
      '🎨 Street art tour'
    ]),
    DateQuestion('act_hobby_swap', '🔄', 'Teach each other a hobby?',
        ['🎸 Music', '🍳 Cooking', '🎮 Gaming', '🧶 Crafts']),
    DateQuestion('act_pottery_wheel', '🏺', "At the pottery wheel we'd be…", [
      '🎬 Very romantic',
      '🫠 Total mess',
      '🏆 Secretly great',
      '😂 Laughing nonstop'
    ]),
    DateQuestion('act_skydive_level', '🪂', 'How brave is our date?',
        ['🛋️ Couch level', '🎢 Roller coaster', '🪢 Zipline', '🪂 Skydive']),
    DateQuestion('act_festival_game', '🎯', 'Fair game to win a prize?', [
      '🎯 Ring toss',
      '🔫 Balloon shoot',
      '🦆 Duck pond',
      '🔨 Strength test'
    ]),
    DateQuestion('act_ice_breaker', '🧊', 'Icebreaker on our date?', [
      '❓ 36 questions',
      '🃏 Card deck game',
      '🎲 Truth or dare (mild)',
      '📸 Swap camera rolls'
    ]),
    DateQuestion('act_mirror', '🪞', 'Silly challenge?', [
      '🪞 Mirror each other',
      '🤐 No-laugh contest',
      '👁️ Staring contest',
      '🗣️ Accent swap'
    ]),
    DateQuestion('act_hidden_talent', '🤹', 'Hidden talent to show?',
        ['🤹 Juggling', '🎶 Whistling', '🧠 Memory trick', '👅 Tongue roll']),
    DateQuestion('act_planting', '🌳', 'Plant a tree together named…',
        ['🌳 After us', '🍕 After a food', '🐶 After a pet', '🎲 Random name']),
    DateQuestion('act_letter', '💌', 'Write each other…', [
      '💌 Love letters',
      '📜 Funny poems',
      '🗒️ Compliment lists',
      '🎨 Doodles'
    ]),
    DateQuestion('act_time_capsule', '⏳', 'Time capsule item?',
        ['📸 Photo', '💌 Letter', '🎟️ Ticket stub', '🎵 Playlist']),
    DateQuestion('act_shopping_date', '🛍️', 'Shopping date?',
        ['👗 Clothes', '📚 Books', '🏠 Home decor', '🎮 Gadgets']),
    DateQuestion('act_chores_fun', '🧹', 'Turn a chore into a date?', [
      '🧺 Laundry & music',
      '🍳 Meal prep party',
      '🧹 Cleaning race',
      '🛒 Grocery game'
    ]),
    DateQuestion('act_paint_night', '🖌️', 'Paint night subject?',
        ['🌅 Sunset', '🌸 Flowers', '🐱 A pet', '🎨 Abstract chaos']),
    DateQuestion('act_astro_chat', '🌠', "Under the stars we'd talk about…",
        ['👽 Aliens', '💭 Dreams', '🎂 Childhood', '🌍 Travel plans']),
    DateQuestion('act_sing_along', '🎶', 'Car sing-along anthem?',
        ['🎶 Arijit Singh', '🎤 Taylor Swift', '🎸 Queen', '🪩 ABBA']),
    DateQuestion('act_dance_floor', '🪩', 'On the dance floor, we…', [
      '🕺 Own it',
      '🙈 Hide by snacks',
      '💃 Copy others',
      '😂 Silly moves only'
    ]),
    DateQuestion('act_explore_city', '🏙️', 'Tourist in our own city?', [
      '🚌 Hop-on bus',
      '🚶 Walking tour',
      '🛺 Auto ride tour',
      '🚲 Bike rental'
    ]),
    DateQuestion(
        'act_learn_instrument',
        '🎹',
        "Instrument we'd learn together?",
        ['🎸 Guitar', '🎹 Piano', '🥁 Drums', '🪕 Ukulele']),
    DateQuestion('act_reading_aloud', '📖', 'Read aloud to each other?',
        ['📖 Poetry', '🧚 Fairy tales', '📰 Weird news', '💬 Old chats']),
    DateQuestion('time_of_day', '🕰️', 'Best time for our date?',
        ['🌅 Morning', '☀️ Afternoon', '🌇 Evening', '🌙 Late night']),
    DateQuestion('time_day_of_week', '📅', 'Which day for our date?', [
      '🗓️ Friday night',
      '🛌 Lazy Sunday',
      '🌤️ Saturday',
      '🤫 Random Tuesday'
    ]),
    DateQuestion('time_duration', '⏳', 'How long should the date last?',
        ['⚡ One hour', '🌇 Half a day', '🌞 All day', '🌙 Till sunrise']),
    DateQuestion('time_early_late', '⏰', 'Are we early or late?', [
      '⏰ 10 mins early',
      '🎯 Exactly on time',
      '🐢 Fashionably late',
      '😅 Very late, sorry'
    ]),
    DateQuestion('time_sunrise_sunset', '🌄', 'Sunrise or sunset?',
        ['🌅 Sunrise', '🌇 Sunset', '🌙 Moonrise', '🌌 Starry midnight']),
    DateQuestion('time_golden_hour', '🌇', 'What do we do at golden hour?', [
      '📸 Take photos',
      '🚶 Walk slowly',
      '🍹 Sip something',
      '🤐 Just watch'
    ]),
    DateQuestion(
        'time_breakfast_dinner',
        '🍽️',
        'Breakfast date or dinner date?',
        ['🥞 Breakfast', '🥪 Lunch', '☕ Evening snacks', '🍝 Dinner']),
    DateQuestion('time_weekend_plan', '🗓️', 'Perfect weekend together?', [
      '🧳 Quick getaway',
      '🛋️ Stay in',
      '🎉 Packed with plans',
      '🎲 Decide that day'
    ]),
    DateQuestion('time_plan_level', '📋', 'How planned should it be?', [
      '📋 Every minute',
      '🗺️ Rough plan',
      '🎲 Fully spontaneous',
      '🤝 One plans each half'
    ]),
    DateQuestion('time_holiday_morning', '☕', 'Holiday morning together?', [
      '😴 Sleep in',
      '🥞 Big breakfast',
      '🏃 Early adventure',
      '📺 Cartoons & cereal'
    ]),
    DateQuestion('time_reply_speed', '📱', 'Texting after the date?', [
      '⚡ Instantly',
      '🕐 Within an hour',
      '🌙 Before bed',
      '🌅 Next morning'
    ]),
    DateQuestion('time_rush_hour', '🚦', 'Stuck in traffic, we…', [
      '🎶 Car karaoke',
      '🎲 Play 20 questions',
      '🍿 Eat snacks',
      '😴 Nap (passenger only)'
    ]),
    DateQuestion('time_wait_line', '🧍', 'Long queue for food?', [
      '⏳ Worth the wait',
      '🏃 Find another place',
      '📱 Order delivery',
      '🎲 Play games in line'
    ]),
    DateQuestion('time_curfew', '🌙', 'What time does our date end?',
        ['🕘 9 PM', '🕚 11 PM', '🕛 Midnight', '🌅 Never']),
    DateQuestion('time_season', '🍂', 'Best season for dating?',
        ['🌸 Spring', '☀️ Summer', '🍂 Autumn', '❄️ Winter']),
    DateQuestion('time_new_year', '🎆', "New Year's Eve together?", [
      '🎆 Big fireworks',
      '🏠 Cozy home',
      '🎉 House party',
      '😴 Asleep by 10'
    ]),
    DateQuestion('weather_ideal', '🌤️', 'Perfect weather for our date?',
        ['☀️ Sunny', '🌧️ Light rain', '❄️ Snowy', '🌬️ Breezy & cool']),
    DateQuestion('weather_rain_plan', '☔', 'It starts raining. We…', [
      '💃 Dance in it',
      '🏃 Run for cover',
      '☂️ Share one umbrella',
      '🛺 Grab an auto'
    ]),
    DateQuestion('weather_hot', '🥵', 'Super hot day plan?',
        ['🏊 Pool', '🍧 Gola stall', '🏬 Air-conditioned mall', '🌊 Beach']),
    DateQuestion('weather_cold', '🥶', 'Freezing day plan?', [
      '☕ Hot drinks',
      '🧣 Matching scarves',
      '🔥 Bonfire',
      '🛋️ Blankets inside'
    ]),
    DateQuestion('weather_storm', '⛈️', 'Thunderstorm night?', [
      '🕯️ Candles & stories',
      '🎬 Movie',
      '🌩️ Watch lightning',
      '😴 Sleep through it'
    ]),
    DateQuestion('weather_fog', '🌫️', 'Foggy morning?', [
      '🚶 Mysterious walk',
      '☕ Café window',
      '📸 Moody photos',
      '🛌 Stay in bed'
    ]),
    DateQuestion('weather_monsoon', '🌦️', 'Monsoon must-do?',
        ['🧅 Pakode', '🚗 Long drive', '🌊 Waterfall trip', '📖 Book & chai']),
    DateQuestion('weather_snow_fight', '☃️', 'Snowball fight teams?', [
      '🤝 Us vs world',
      '⚔️ You vs me',
      '🏳️ Instant surrender',
      '🧱 Build forts first'
    ]),
    DateQuestion('weather_rainbow', '🌈', 'We spot a rainbow. We…',
        ['📸 Photo', '🌈 Make a wish', '🏃 Chase the end', '🎶 Sing about it']),
    DateQuestion('weather_umbrella', '☂️', 'Only one umbrella?', [
      '☂️ Share it',
      '💦 Both get wet',
      '🤲 You take it',
      '🏃 Run together'
    ]),
    DateQuestion('weather_windy', '🌬️', 'Windy day idea?',
        ['🪁 Fly kites', '🌊 Watch waves', '⛵ Sailing', '🏠 Stay in']),
    DateQuestion('weather_cloudy', '☁️', 'Cloudy day game?', [
      '☁️ Find cloud shapes',
      '📸 Moody photos',
      '🚲 Bike ride',
      '🎬 Movie'
    ]),
    DateQuestion('weather_heatwave_food', '🍉', 'Best heatwave snack?',
        ['🍉 Watermelon', '🥭 Mango', '🍦 Ice cream', '🥒 Cucumber with salt']),
    DateQuestion('weather_forecast', '📡', 'We check the forecast…',
        ['📡 Always', '🤷 Never', '☔ Umbrella anyway', '🎲 Trust our luck']),
    DateQuestion('travel_dream', '✈️', 'Dream trip together?',
        ['🗼 Paris', '🗻 Japan', '🏝️ Maldives', '🏔️ Ladakh']),
    DateQuestion('travel_style', '🧳', 'Travel style?',
        ['🎒 Backpacking', '🏨 Comfy hotels', '🏕️ Camping', '🚐 Van life']),
    DateQuestion('travel_packing', '👜', 'Packing style?', [
      '🪶 Super light',
      '🧳 Overpacker',
      '📝 Checklist pro',
      '⏰ Last-minute chaos'
    ]),
    DateQuestion('travel_trip_length', '📆', 'Trip length?',
        ['🌙 Weekend', '📅 One week', '🗓️ Two weeks', '🌍 Months abroad']),
    DateQuestion('travel_india_trip', '🇮🇳', 'Indian getaway?',
        ['🏖️ Goa', '🏔️ Manali', '🌴 Kerala', '🏰 Rajasthan']),
    DateQuestion('travel_world_city', '🌍', 'City to visit together?',
        ['🗽 New York', '🏯 Kyoto', '🏛️ Rome', '🕌 Istanbul']),
    DateQuestion('travel_beach_country', '🏝️', 'Beach destination?',
        ['🇹🇭 Thailand', '🇮🇩 Bali', '🇱🇰 Sri Lanka', '🇬🇷 Greek islands']),
    DateQuestion('travel_mountain', '🏔️', 'Mountain trip?', [
      '🇨🇭 Swiss Alps',
      '🏔️ Himalayas',
      '🇳🇵 Nepal trek',
      '🇳🇿 New Zealand'
    ]),
    DateQuestion('travel_stay', '🏨', 'Where do we stay?',
        ['🏨 Hotel', '🏡 Homestay', '⛺ Tent', '🛖 Treehouse']),
    DateQuestion('travel_planner', '🗺️', 'Who plans the trip?',
        ['🙋 Me', '👉 You', '🤝 Together', '🧭 We wing it']),
    DateQuestion('travel_window_aisle', '💺', 'Window or aisle?', [
      '🪟 Window',
      '🚶 Aisle',
      '🤝 You get window',
      "😴 Don't care, sleeping"
    ]),
    DateQuestion('travel_souvenir', '🧲', 'Souvenir we collect?',
        ['🧲 Fridge magnets', '📮 Postcards', '☕ Mugs', '🪨 Little stones']),
    DateQuestion('travel_photos', '📸', 'Travel photos?', [
      '🤳 Selfies everywhere',
      '🏞️ Scenery only',
      '🎥 Video diaries',
      '📵 Just live it'
    ]),
    DateQuestion('travel_food_abroad', '🍜', 'Eating abroad?', [
      '🍜 Only local food',
      '🍕 Familiar comfort',
      '🔀 Mix',
      '🧑‍🍳 Cook in Airbnb'
    ]),
    DateQuestion('travel_airport', '🛫', 'At the airport we…', [
      '☕ People-watching',
      '🛍️ Duty-free browse',
      '😴 Nap at gate',
      '🏃 Always running late'
    ]),
    DateQuestion('travel_road_or_fly', '🛣️', 'Road trip or flight?',
        ['🚗 Road trip', '✈️ Flight', '🚆 Train', '🚌 Bus adventure']),
    DateQuestion('travel_road_snacks', '🍟', 'Road trip snack bag?',
        ['🥔 Chips', '🍪 Biscuits', '🥜 Namkeen', '🍫 Chocolates']),
    DateQuestion('travel_music', '🎵', 'Road trip DJ?',
        ['🙋 Me', '👉 You', '🔀 Take turns', '📻 Radio roulette']),
    DateQuestion('travel_getaway_type', '🏡', 'Weekend getaway?', [
      '🏞️ Nature retreat',
      '🏙️ New city',
      '🧘 Wellness stay',
      '🏖️ Beach shack'
    ]),
    DateQuestion('travel_adventure_level', '🧭', 'Trip adventure level?', [
      '🛋️ Relax only',
      '🚶 Light sightseeing',
      '🥾 Active days',
      '🪂 Extreme adventure'
    ]),
    DateQuestion('travel_unknown', '🎲', 'Surprise destination?', [
      '🎲 Love it',
      '😬 Nervous but yes',
      '🗺️ Need to know',
      '🙅 No thanks'
    ]),
    DateQuestion('travel_backup', '🧭', 'Lost in a new city, we…', [
      '🗺️ Use a map',
      '🙋 Ask locals',
      '🎲 Explore anyway',
      '☕ Find a café, regroup'
    ]),
    DateQuestion('travel_hostel_hotel', '🛏️', 'Budget trip stay?', [
      '🛏️ Hostel',
      '🏨 Budget hotel',
      '🏡 Couch surfing',
      '🚐 Sleep in car'
    ]),
    DateQuestion('travel_bucket_wonder', '🌐', 'World wonder to see?',
        ['🕌 Taj Mahal', '🧱 Great Wall', '⛰️ Machu Picchu', '🏺 Petra']),
    DateQuestion('travel_northern', '🌌', 'Natural wonder?', [
      '🌌 Northern lights',
      '🌋 Volcano',
      '🐋 Whale watching',
      '🏜️ Sand dunes'
    ]),
    DateQuestion('travel_cruise', '🚢', 'Cruise or train journey?',
        ['🚢 Cruise', '🚂 Scenic train', '🚤 Houseboat', '🛩️ Seaplane']),
    DateQuestion('travel_itinerary', '📒', 'Itinerary style?', [
      '🗓️ Packed days',
      '🌴 Lots of free time',
      '☕ One plan per day',
      '🎲 None at all'
    ]),
    DateQuestion('travel_long_flight', '🛬', 'Long flight activity?',
        ['🎬 Movies', '😴 Sleep', '📖 Read', '💬 Talk the whole way']),
    DateQuestion('travel_rain_trip', '🌧️', 'Trip rained out?', [
      '🏨 Room movie day',
      '☔ Explore anyway',
      '🍲 Food crawl',
      '🛍️ Mall hop'
    ]),
    DateQuestion('transport_how', '🚗', 'How do we get to our date?',
        ['🚶 Walk', '🛺 Auto rickshaw', '🚇 Metro', '🚗 Car']),
    DateQuestion('transport_fun', '🛵', 'Most fun ride?',
        ['🛵 Scooter', '🚲 Tandem bike', '🚤 Speedboat', '🚡 Cable car']),
    DateQuestion('transport_long_drive', '🛣️', 'Long drive essential?',
        ['🎶 Playlist', '🍿 Snacks', '🗺️ Scenic route', '☕ Chai stops']),
    DateQuestion('transport_who_drives', '🚘', 'Who drives?',
        ['🙋 Me', '👉 You', '🔁 Take turns', '🚕 Neither, cab']),
    DateQuestion('transport_public', '🚌', 'Public transport adventure?',
        ['🚇 Metro', '🚌 Double-decker', '🚋 Tram', '⛴️ Ferry']),
    DateQuestion('transport_vintage', '🚂', 'Vintage ride?', [
      '🚂 Toy train',
      '🐎 Horse carriage',
      '🚘 Classic car',
      '🚲 Old cycle'
    ]),
    DateQuestion('transport_dream', '🏎️', 'Dream ride for a date?',
        ['🏎️ Sports car', '🎈 Hot air balloon', '🛥️ Yacht', '🚁 Helicopter']),
    DateQuestion('transport_scooter', '🛵', "On a scooter, you'd be…",
        ['🧑‍✈️ Driving', '🎒 Riding pillion', '🗺️ Navigating', '📸 Filming']),
    DateQuestion('transport_cab_music', '📻', 'Cab music request?',
        ['🎶 Old Bollywood', '🎵 Lo-fi', '🎸 Rock', '🔇 Silence please']),
    DateQuestion('transport_bike_share', '🚲', 'Bike rental color?',
        ['🔴 Red', '🔵 Blue', '🟡 Yellow', "🌈 Whatever's free"]),
    DateQuestion('transport_train_seat', '🚆', 'Train journey seat?', [
      '🔝 Upper berth',
      '⬇️ Lower berth',
      '🪟 Window seat',
      '🚪 Near the door'
    ]),
    DateQuestion('transport_walk_home', '🌃', 'After dinner, we…',
        ['🚶 Walk home', '🚕 Grab a cab', '🛺 Auto ride', '🚇 Last metro']),
    DateQuestion('transport_boat', '🛶', 'Boat type?',
        ['🛶 Rowboat', '🦢 Swan pedal boat', '⛵ Sailboat', '🚤 Motorboat']),
    DateQuestion('music_genre', '🎵', 'Soundtrack for our date?',
        ['🎶 Bollywood', '🎸 Rock', '🎷 Jazz', '🎧 Lo-fi']),
    DateQuestion('music_concert', '🎤', "Concert we'd go to?",
        ['🎤 Pop star', '🎸 Indie band', '🎻 Orchestra', '🎶 Sufi night']),
    DateQuestion('music_love_song', '💕', 'Our song era?',
        ['📼 90s', '💿 2000s', '📱 2010s', '🆕 This year']),
    DateQuestion('music_instrument_sound', '🎼', 'Most romantic instrument?',
        ['🎻 Violin', '🎹 Piano', '🎸 Guitar', '🪈 Flute']),
    DateQuestion('music_playlist_name', '📝', 'Our shared playlist name?',
        ['💕 Us Two', '🚗 Drive Mode', '🌙 Late Night Vibes', '🎲 Chaos Mix']),
    DateQuestion('music_dance_song', '💃', 'First dance song mood?', [
      '🐢 Slow & sweet',
      '🪩 Upbeat',
      '😂 Totally silly',
      '🎶 Bollywood classic'
    ]),
    DateQuestion('music_volume', '🔊', 'Music volume on a date?',
        ['🔇 Background hum', '🔉 Medium', '🔊 Loud', '🎧 Shared earphones']),
    DateQuestion('music_shower_singer', '🚿', "Who's the shower singer?",
        ['🙋 Me', '👉 You', '🎤 Both of us', '🤐 Neither']),
    DateQuestion('music_record_store', '💿', 'Record store find?',
        ['💿 Old vinyl', '📼 Cassette tape', '🎵 Rare CD', '📻 Retro radio']),
    DateQuestion('music_festival', '🎪', 'Music festival vibe?', [
      '🎸 Rock fest',
      '🎧 EDM festival',
      '🪕 Folk fest',
      '🎻 Classical evening'
    ]),
    DateQuestion('music_singer', '🎙️', 'Singer for our date soundtrack?', [
      '🎶 Arijit Singh',
      '🎤 Ed Sheeran',
      '💃 Shreya Ghoshal',
      '🎸 Coldplay'
    ]),
    DateQuestion('music_lyrics', '📜', 'We mess up lyrics by…', [
      '🎵 Humming',
      '🤪 Making them up',
      '🗣️ Shouting the chorus',
      '🤐 Lip-syncing'
    ]),
    DateQuestion('music_genre_never', '🙉', "Genre we'd skip?",
        ['🤘 Heavy metal', '🤠 Country', '🎺 Opera', '🎶 None, love all']),
    DateQuestion('music_cover_band', '🎸', 'If we started a band…',
        ['🎤 You sing', '🥁 I drum', '🎹 Keytar duo', '📣 Both just dance']),
    DateQuestion('music_morning_tune', '🌅', 'Morning playlist?', [
      '☀️ Happy pop',
      '🎻 Soft classical',
      '🌿 Calm acoustic',
      '🎧 Upbeat workout'
    ]),
    DateQuestion('music_retro', '📻', 'Retro music night?',
        ['🕺 Disco', '🎙️ Kishore Kumar', '🎸 70s rock', '🎷 Swing']),
    DateQuestion('movie_genre', '🎬', 'If our date were a movie genre…',
        ['💕 Rom-com', '🧭 Adventure', '🔍 Mystery', '😂 Comedy']),
    DateQuestion('movie_night_pick', '🍿', 'Movie night pick?',
        ['😂 Comedy', '😱 Horror', '🦸 Superhero', '💕 Romance']),
    DateQuestion('movie_watch_where', '📺', 'Where do we watch?',
        ['🎬 Cinema', '🛋️ Couch', '🚗 Drive-in', '🌳 Open-air screen']),
    DateQuestion('movie_classic', '🎞️', 'Classic to rewatch?',
        ['💃 DDLJ', '🚢 Titanic', '🧙 Harry Potter', '🦁 The Lion King']),
    DateQuestion('movie_animated', '🧸', 'Animated movie?',
        ['🐟 Finding Nemo', '❄️ Frozen', '🏠 Up', '🍝 Ratatouille']),
    DateQuestion('movie_horror_reaction', '😱', 'During a horror movie, we…', [
      '🙈 Hide behind pillows',
      '😂 Laugh at it',
      '🗣️ Yell at the screen',
      '😴 Fall asleep'
    ]),
    DateQuestion('movie_snack', '🍿', 'Popcorn flavor?',
        ['🧂 Salted', '🍯 Caramel', '🧀 Cheese', '🔀 Half & half']),
    DateQuestion('movie_talking', '🤫', 'Talking during a movie?', [
      '🤐 Total silence',
      '💬 Little whispers',
      '🗣️ Full commentary',
      '⏸️ Pause and discuss'
    ]),
    DateQuestion('movie_trilogy', '🎥', 'Marathon a trilogy?', [
      '💍 Lord of the Rings',
      '⭐ Star Wars',
      '🕷️ Spider-Man',
      '🔙 Back to the Future'
    ]),
    DateQuestion('movie_be_in', '🌟', 'Which movie world would we live in?', [
      '🧙 Hogwarts',
      '🦖 Jurassic Park',
      "🌊 Moana's island",
      '🚀 Star Wars galaxy'
    ]),
    DateQuestion('movie_series', '📺', 'Binge-worthy show type?', [
      '🔍 Crime thriller',
      '😂 Sitcom',
      '🐉 Fantasy epic',
      '🍳 Cooking show'
    ]),
    DateQuestion('movie_kdrama', '🌸', 'K-drama, anime, or sitcom?',
        ['🌸 K-drama', '🍥 Anime', '😂 Sitcom', '🎭 Indian web series']),
    DateQuestion('movie_reality', '📺', "Reality show we'd join?", [
      '🍳 Cooking contest',
      '🏝️ Survival island',
      '💃 Dance show',
      '🏠 Home makeover'
    ]),
    DateQuestion('movie_cry', '😢', 'Do we cry at movies?',
        ['😭 Every time', '🥲 Sometimes', '😎 Never', '🙈 Secretly']),
    DateQuestion('movie_rating', '⭐', 'Who picks the movie?',
        ['🙋 Me', '👉 You', '🎲 Random spin', '🗳️ Online ratings']),
    DateQuestion('movie_rewatch', '🔁', 'Rewatch favorites or something new?',
        ['🔁 Rewatch', '🆕 New', '🎲 Coin toss', '📺 One of each']),
    DateQuestion('movie_director', '🎬', 'If we directed our love story…',
        ['💕 Romance', '🤠 Western', '👽 Sci-fi', '🎭 Musical']),
    DateQuestion('movie_cast', '🎭', 'Who plays us in our movie?',
        ['🌟 Superstars', '😂 Comedians', '🧸 Cartoon voices', '🙋 Ourselves']),
    DateQuestion('movie_bollywood_era', '🇮🇳', 'Bollywood era?', [
      '🎞️ 70s classics',
      '📼 90s romance',
      '💿 2000s hits',
      '🆕 Latest films'
    ]),
    DateQuestion('movie_documentary', '🐋', 'Documentary topic?',
        ['🐋 Ocean life', '🚀 Space', '🍜 Food', '🕵️ True crime']),
    DateQuestion('movie_cinema_time', '🎟️', 'Movie show time?', [
      '🌅 Morning show',
      '☀️ Matinee',
      '🌇 Evening',
      '🌙 Midnight premiere'
    ]),
    DateQuestion('game_couple', '🎮', 'Game night together?',
        ['🎲 Board games', '🎮 Console', '🃏 Cards', '📱 Phone games']),
    DateQuestion('game_winner_prize', '🏆', 'Loser of our game must…',
        ['🍦 Buy dessert', '💃 Do a dance', '🍽️ Do dishes', '🎤 Sing a song']),
    DateQuestion('game_co_op', '🤝', 'Co-op or versus?',
        ['🤝 Co-op', '⚔️ Versus', '🔀 Switch it up', "🙈 I'll watch"]),
    DateQuestion('game_party', '🎉', 'Party game?',
        ['🎭 Charades', '🖍️ Pictionary', '🐺 Werewolf', '💣 Taboo']),
    DateQuestion('game_retro', '👾', 'Retro game?',
        ['🐍 Snake', '🧱 Tetris', '🍄 Super Mario', '👻 Pac-Man']),
    DateQuestion('game_mobile', '📱', 'Phone game duel?',
        ['🎲 Ludo King', '🐦 Angry Birds', '🍬 Candy Crush', '🔤 Word game']),
    DateQuestion('game_strategy', '♟️', 'Strategy game?',
        ['♟️ Chess', '🏝️ Catan', '🗺️ Risk', '🀄 Mahjong']),
    DateQuestion('game_outdoor_classic', '🏃', 'Childhood outdoor game?', [
      '🙈 Hide and seek',
      '🏃 Tag',
      '🪨 Pittu / seven stones',
      '🪢 Tug of war'
    ]),
    DateQuestion('game_cheater', '😏', "Who's more likely to cheat at games?",
        ['🙋 Me', '👉 You', '😇 Neither', '😂 Both, shamelessly']),
    DateQuestion('game_rage', '😤', 'After losing a game, we…', [
      '😂 Laugh it off',
      '🔁 Demand a rematch',
      '😤 Sulk briefly',
      '🍦 Eat ice cream'
    ]),
    DateQuestion('game_vr', '🥽', 'VR experience?', [
      '🧟 Zombie escape',
      '🎢 Virtual coaster',
      '🌌 Space walk',
      '🎾 Virtual sports'
    ]),
    DateQuestion('game_quiz_app', '❓', 'Quiz battle topic?',
        ['🌍 Capitals', '🎬 Movie quotes', '🧠 Science', '🍕 Food facts']),
    DateQuestion('game_casino_alt', '🎰', 'Snack-stakes card night with…',
        ['🍬 Candy chips', '🪙 Coins', '🍪 Cookies', '🃏 Matchsticks']),
    DateQuestion('game_lan', '🖥️', 'Gaming setup?',
        ['🖥️ PC', '🎮 Console', '📱 Mobile', '🕹️ Arcade cabinet']),
    DateQuestion('sport_watch', '🏟️', 'Which sport do we watch together?',
        ['🏏 Cricket', '⚽ Football', '🎾 Tennis', '🏎️ F1']),
    DateQuestion('sport_play', '🏸', 'Which sport do we play?',
        ['🏸 Badminton', '🏓 Table tennis', '🏐 Volleyball', '⛳ Golf']),
    DateQuestion('sport_cricket_role', '🏏', 'Gully cricket roles?', [
      '🏏 You bat, I bowl',
      '🎯 I bat, you bowl',
      '🧤 Both field',
      '📢 Both umpire'
    ]),
    DateQuestion('sport_team', '🤝', 'Team name for us?', [
      '🔥 The Blazers',
      '🌙 Night Owls',
      '🍕 Pizza Squad',
      '💕 Dynamic Duo'
    ]),
    DateQuestion('sport_fan', '📣', 'How loud are we as fans?', [
      '📣 Screaming',
      '👏 Polite claps',
      '🫣 Too nervous',
      '😴 Watching for snacks'
    ]),
    DateQuestion('sport_match_snack', '🌭', 'Match-day snack?',
        ['🌭 Hot dog', '🍿 Popcorn', '🥟 Samosa', '🍕 Pizza']),
    DateQuestion('sport_olympics', '🥇', "Olympic event we'd win?", [
      '🏃 Sprint',
      '🏊 Swimming',
      '🤸 Gymnastics',
      '🛋️ Competitive napping'
    ]),
    DateQuestion('sport_extreme', '🏄', 'Extreme sport to try?',
        ['🏄 Surfing', '🏂 Snowboarding', '🪂 Skydiving', '🤿 Scuba']),
    DateQuestion('sport_winter', '⛷️', 'Winter sport?',
        ['⛷️ Skiing', '⛸️ Ice skating', '🛷 Sledding', '🥌 Curling']),
    DateQuestion('sport_racket', '🎾', 'Racket sport?',
        ['🎾 Tennis', '🏸 Badminton', '🏓 Ping pong', '🥒 Pickleball']),
    DateQuestion('sport_martial', '🥋', 'Martial arts class?',
        ['🥋 Karate', '🥊 Kickboxing', '🤺 Fencing', '🧘 Tai chi']),
    DateQuestion('sport_water_sport', '🚣', 'Water sport?',
        ['🚣 Rowing', '🤽 Water polo', '🏄 Paddleboard', '🛶 Canoe race']),
    DateQuestion('sport_jersey', '👕', 'Matching jerseys?', [
      '👕 Same team',
      '⚔️ Rival teams',
      '🙅 No jerseys',
      '🎨 Custom couple jersey'
    ]),
    DateQuestion('sport_morning_walk', '🚶', 'Morning fitness together?',
        ['🚶 Brisk walk', '🏃 Jog', '🧘 Yoga', '💃 Zumba']),
    DateQuestion('sport_dance_fitness', '💃', 'Dance workout?', [
      '💃 Zumba',
      '🩰 Ballet barre',
      '🕺 Hip-hop cardio',
      '🪩 Bollywood fitness'
    ]),
    DateQuestion('sport_climb', '🧗', 'Climbing date?', [
      '🧗 Indoor wall',
      '🏔️ Real rock',
      '🪜 Rope course',
      '🌳 Treetop adventure'
    ]),
    DateQuestion('sport_cheer', '🎉', 'Our victory celebration?',
        ['🙌 High five', '🕺 Victory dance', '🤗 Big hug', '📸 Trophy selfie']),
    DateQuestion('sport_marathon', '🏅', 'Charity run costume?', [
      '🦸 Superheroes',
      '🍌 Fruit costumes',
      '🐻 Animal onesies',
      '👟 Just running gear'
    ]),
    DateQuestion('outfit_vibe', '👗', 'Dress code for our date?', [
      '👕 Casual comfy',
      '✨ Dressed up',
      '🎨 Matching colors',
      '🎲 Wear something wild'
    ]),
    DateQuestion('outfit_color', '🎨', 'Our date-night color?',
        ['🖤 Black', '🤍 White', '❤️ Red', '💙 Blue']),
    DateQuestion('outfit_matching', '👯', 'Matching outfits?', [
      '👯 Fully matching',
      '🎨 Same color only',
      '🧦 Just socks',
      '🙅 Never'
    ]),
    DateQuestion('outfit_shoes', '👟', 'Shoes for the date?',
        ['👟 Sneakers', '👞 Formal shoes', '🩴 Sandals', '🥾 Boots']),
    DateQuestion('outfit_ethnic', '🪔', 'Ethnic wear day?', [
      '👘 Kurta set',
      '🥻 Saree / drape',
      '🧥 Nehru jacket',
      '🎨 Indo-western'
    ]),
    DateQuestion('outfit_accessory', '💍', 'Must-have accessory?',
        ['⌚ Watch', '🕶️ Sunglasses', '🧣 Scarf', '🧢 Cap']),
    DateQuestion('outfit_theme', '🎭', 'Theme dress-up date?',
        ['🕺 Retro 70s', '🧙 Fantasy', '🦸 Superheroes', '🤠 Cowboy']),
    DateQuestion('outfit_comfort', '🛋️', 'Comfort level?', [
      '🩳 Pajamas allowed',
      '👖 Jeans & tee',
      '👔 Smart casual',
      '🤵 Full formal'
    ]),
    DateQuestion('outfit_winter', '🧥', 'Winter look?', [
      '🧥 Big puffer',
      '🧶 Cozy sweater',
      '🧣 Long coat',
      '🧤 Gloves & beanie'
    ]),
    DateQuestion('outfit_summer', '🌞', 'Summer look?',
        ['👕 Linen shirt', '🩳 Shorts', '👗 Flowy dress', '🧢 Cap & tee']),
    DateQuestion('outfit_hoodie', '🧥', 'Hoodie situation?', [
      '🧥 Wear my hoodie',
      '🔁 Swap hoodies',
      '🎨 Matching hoodies',
      '🙅 No hoodies'
    ]),
    DateQuestion('outfit_perfume', '🌸', 'Signature scent vibe?',
        ['🌸 Floral', '🍋 Fresh citrus', '🌲 Woody', '🍦 Sweet vanilla']),
    DateQuestion('outfit_hair', '💇', 'Hair for the date?', [
      '💁 Freshly styled',
      '🌀 Messy & natural',
      '🧢 Hat day',
      '🎀 Something fun'
    ]),
    DateQuestion('outfit_glasses', '🕶️', 'Sunglasses style?', [
      '🕶️ Aviators',
      '😎 Wayfarers',
      '🔴 Round retro',
      '🌈 Colorful funky'
    ]),
    DateQuestion('outfit_fancy_level', '💎', 'How fancy is our date?',
        ['🩴 Super chill', '👕 Neat casual', '👔 Smart', '💎 Red carpet']),
    DateQuestion(
        'outfit_pick_for_me', '👚', "Would we pick each other's outfit?", [
      '💯 Yes, fun',
      '🤔 Only accessories',
      '🙅 Never',
      '🎲 Blindfolded pick'
    ]),
    DateQuestion('outfit_costume', '🎃', 'Couple costume?', [
      '🍞 Bread & butter',
      '🧂 Salt & pepper',
      '🦸 Hero & sidekick',
      '🍪 Milk & cookies'
    ]),
    DateQuestion('outfit_pattern', '🧩', 'Pattern pick?',
        ['⚫ Plain solids', '🦓 Stripes', '🌸 Florals', '🟥 Checks']),
    DateQuestion('outfit_jewelry', '📿', 'Jewelry style?',
        ['✨ Minimal', '📿 Statement', '🔗 Chain & rings', '🙅 None']),
    DateQuestion('outfit_rain', '🌧️', 'Rainy day fashion?',
        ['🧥 Raincoat', '🥾 Gumboots', '☂️ Cute umbrella', '🩴 Flip-flops']),
    DateQuestion('gift_first', '🎁', 'First little gift?',
        ['💐 Flowers', '🍫 Chocolates', '📚 A book', '💌 Handwritten note']),
    DateQuestion('gift_flowers', '💐', 'Flowers to give?',
        ['🌹 Roses', '🌻 Sunflowers', '🌷 Tulips', '🌼 Marigolds']),
    DateQuestion('gift_handmade', '🧶', 'Handmade gift?', [
      '🧶 Knitted scarf',
      '🎨 Painting',
      '📒 Scrapbook',
      '🍪 Baked goodies'
    ]),
    DateQuestion('gift_experience', '🎟️', 'Experience gift?', [
      '🎤 Concert tickets',
      '🧖 Spa voucher',
      '🍳 Cooking class',
      '🎈 Balloon ride'
    ]),
    DateQuestion('gift_budget', '💸', 'Gift budget vibe?', [
      '💸 Tiny but thoughtful',
      '💳 Mid-range',
      '💎 Splurge',
      '🆓 Free & homemade'
    ]),
    DateQuestion('gift_tech', '📱', 'Tech gift?',
        ['🎧 Earbuds', '⌚ Smartwatch', '📷 Instant camera', '🔊 Mini speaker']),
    DateQuestion('gift_plant', '🪴', 'Plant gift?',
        ['🌵 Cactus', '🪴 Money plant', '🌿 Bonsai', '🌺 Orchid']),
    DateQuestion('gift_surprise_style', '🎉', 'How do we give gifts?', [
      '🎁 Wrapped surprise',
      '🗺️ Treasure hunt',
      '📦 Hidden in a box',
      '👋 Just hand it over'
    ]),
    DateQuestion('gift_wrap', '🎀', 'Wrapping style?', [
      '🎀 Perfect bows',
      '📰 Newspaper chic',
      '🛍️ Gift bag',
      '🫣 Unwrapped, sorry'
    ]),
    DateQuestion('gift_letter', '💌', 'Love letter format?', [
      '✍️ Handwritten',
      '📱 Long text',
      '🎙️ Voice note',
      '🎥 Video message'
    ]),
    DateQuestion('gift_jewelry', '💍', 'Small keepsake?', [
      '📿 Friendship bracelet',
      '🔑 Keychain',
      '🔗 Pendant',
      '💍 Simple ring'
    ]),
    DateQuestion('gift_photo', '🖼️', 'Photo gift?', [
      '🖼️ Framed photo',
      '📒 Photo album',
      '📅 Custom calendar',
      '☕ Photo mug'
    ]),
    DateQuestion('gift_book', '📚', 'Book gift genre?',
        ['💕 Romance', '🔍 Mystery', '🧠 Non-fiction', '📜 Poetry']),
    DateQuestion('gift_sweet', '🍫', 'Sweet gift?',
        ['🍫 Chocolate box', '🎂 Mini cake', '🍬 Mithai box', '🍪 Cookie jar']),
    DateQuestion('gift_cozy', '🧸', 'Cozy gift?', [
      '🧸 Teddy bear',
      '🧦 Fuzzy socks',
      '🛏️ Soft blanket',
      '🕯️ Scented candle'
    ]),
    DateQuestion('gift_anniversary', '💞', 'One-month-anniversary gift?',
        ['💌 Letter', '🍽️ Dinner', '🎟️ Day trip', '🎵 Custom playlist']),
    DateQuestion('gift_playlist', '🎶', 'Playlist gift theme?',
        ['💕 Our story', '🚗 Road trip', '😴 Sleepy songs', '😂 Inside jokes']),
    DateQuestion('gift_star', '⭐', 'Most romantic cheesy gift?', [
      '⭐ Name a star',
      '🔒 Love lock',
      '💌 Message in a bottle',
      '🧩 Custom puzzle'
    ]),
    DateQuestion('gift_food_hamper', '🧺', 'Gift hamper?',
        ['🍫 Chocolates', '🧀 Snacks', '☕ Coffee & tea', '🍯 Jams & honey']),
    DateQuestion('gift_receive', '🎊', 'When we get a gift we…',
        ['😭 Cry happy tears', '🤩 Scream', '🙂 Calm thank you', '🫣 Get shy']),
    DateQuestion('gift_last_minute', '⏰', 'Last-minute gift?', [
      '🍫 Chocolate bar',
      '💐 Roadside flowers',
      '📱 Online voucher',
      '🎶 Sing a song'
    ]),
    DateQuestion('gift_reuse', '♻️', 'Eco-friendly gift?', [
      '🌱 Plant a tree',
      '🛍️ Tote bag',
      '🫙 Reusable bottle',
      '🧼 Handmade soap'
    ]),
    DateQuestion('gift_subscription', '📦', 'Subscription gift?',
        ['🎬 Streaming', '📚 Book club', '☕ Coffee box', '🌸 Flower delivery']),
    DateQuestion('gift_mystery_box', '📦', 'Mystery box contents?',
        ['🍬 Snacks', '🎲 Mini games', '💌 Tiny notes', '🎁 All of the above']),
    DateQuestion('gift_bday_plan', '🎂', 'Birthday date plan?', [
      '🎉 Surprise party',
      '🍽️ Fancy dinner',
      '🏕️ Adventure day',
      '🛋️ Quiet day in'
    ]),
    DateQuestion('gift_coupon', '🎟️', 'Coupon book entry?', [
      '💆 Free massage',
      '🍳 Breakfast in bed',
      '🎬 Movie pick',
      '🧹 Chore pass'
    ]),
    DateQuestion('chat_first_topic', '💬', 'First topic on our date?',
        ['✈️ Travel', '🍜 Food', '🎬 Movies', '🐾 Pets']),
    DateQuestion('chat_deep_light', '🌊', 'Deep talks or light banter?',
        ['🌊 Deep', '😂 Light', '🔀 Both', '🎲 Let it flow']),
    DateQuestion('chat_childhood', '🧒', 'Childhood topic?', [
      '🧸 Fave toys',
      '📺 Cartoons',
      '🏫 School stories',
      '🍬 Candy we loved'
    ]),
    DateQuestion('chat_dreams', '💭', 'Talk about dreams?',
        ['🏡 Dream home', '💼 Dream job', '🌍 Dream trip', '🐶 Dream pet']),
    DateQuestion('chat_funny_story', '😂', 'Story to share?', [
      '😳 Most embarrassing',
      '🤪 Funniest fail',
      '😱 Scariest moment',
      '🥹 Sweetest memory'
    ]),
    DateQuestion('chat_question_game', '❓', 'Question game?', [
      '🤔 Would you rather',
      '❓ 20 questions',
      '🙊 Never have I ever',
      '🎯 Rapid fire'
    ]),
    DateQuestion('chat_unpopular', '🔥', 'Share an unpopular opinion about…',
        ['🍕 Food', '🎬 Movies', '🎶 Music', '📱 Apps']),
    DateQuestion('chat_family', '🏡', 'Family stories?', [
      '👵 Grandparent tales',
      '👫 Sibling chaos',
      '🐶 Pet drama',
      '🍲 Family recipes'
    ]),
    DateQuestion('chat_future', '🔮', 'Future talk on date one?', [
      '🔮 Big dreams',
      '🎯 Small goals',
      '🙅 Too soon',
      '😂 Silly predictions'
    ]),
    DateQuestion('chat_compliment', '💐', 'Best compliment to give?',
        ['😊 Your smile', '🧠 Your mind', '😂 Your humor', '💖 Your kindness']),
    DateQuestion('chat_text_style', '📱', 'Texting style?', [
      '💬 Long paragraphs',
      '⚡ Short and fast',
      '😂 Memes only',
      '🎙️ Voice notes'
    ]),
    DateQuestion('chat_emoji', '😊', 'Our most-used emoji?',
        ['😂 Laughing', '❤️ Heart', '🥺 Pleading', '💀 Skull']),
    DateQuestion('chat_meme', '🐸', 'Meme language?',
        ['🐶 Dog memes', '🐱 Cat memes', '🇮🇳 Desi memes', '🎬 Movie memes']),
    DateQuestion('chat_silence', '🤫', 'Comfortable silence?', [
      '😌 Love it',
      '😬 Awkward',
      '💬 Always talking',
      '🎶 Fill it with music'
    ]),
    DateQuestion('chat_debate', '⚖️', 'Fun debate?', [
      '🍕 Best pizza topping',
      '🐶 Cats vs dogs',
      '🌅 Morning vs night',
      '☕ Tea vs coffee'
    ]),
    DateQuestion('chat_listen_talk', '👂', 'Listener or talker?',
        ['👂 Listener', '🗣️ Talker', '🔀 Both', '📝 Depends on topic']),
    DateQuestion('chat_secret', '🔐', 'Share a little secret?', [
      '🙊 Guilty pleasure song',
      '🍫 Hidden snack stash',
      '📺 Secret show',
      '🧸 Childhood toy'
    ]),
    DateQuestion('chat_pet_names', '💕', 'Cute nickname style?',
        ['🍯 Honey', '🧁 Cupcake', '🐼 Panda', '🙅 Just names']),
    DateQuestion('chat_dealbreaker', '🚫', 'Funniest small dealbreaker?', [
      '🍍 Anti-pineapple pizza',
      '⏰ Always late',
      '📱 Slow replies',
      '🎬 Spoils movies'
    ]),
    DateQuestion('chat_goodnight', '🌙', 'Goodnight text?',
        ['🌙 Sweet dreams', '😴 GN', '🎙️ Voice note', '💌 Long message']),
    DateQuestion('chat_storytime', '📖', 'Story time theme?',
        ['👻 Spooky', '😂 Funny', '🦸 Heroic', '💕 Romantic']),
    DateQuestion('chat_hot_take_food', '🌶️', 'Food hot take to discuss?', [
      '🍍 Pineapple pizza',
      '🥄 Cereal before milk',
      '🍛 Biryani with raita',
      '🍟 Fries in ice cream'
    ]),
    DateQuestion('chat_three_words', '🔤', 'Describe our date in one word?',
        ['✨ Magical', '😂 Hilarious', '☕ Cozy', '🎢 Wild']),
    DateQuestion('chat_dream_job', '💼', 'Silly dream job?', [
      '🍦 Ice cream taster',
      '🐼 Panda nanny',
      '🛏️ Bed tester',
      '🌍 Travel blogger'
    ]),
    DateQuestion('chat_superpower', '🦸', 'Superpower to talk about?',
        ['🦅 Flying', '🫥 Invisibility', '⏳ Time travel', '🧠 Mind reading']),
    DateQuestion('chat_aliens', '👽', 'Fun theory to chat about?', [
      '👽 Aliens exist',
      '🦕 Dinosaurs return',
      '⏳ Time travel',
      '🌊 Mermaids'
    ]),
    DateQuestion('chat_tell_more', '🗨️', 'What makes us talk for hours?',
        ['🎶 Music', '✈️ Travel', '🍜 Food', '📚 Books']),
    DateQuestion('pet_bring', '🐾', 'Pet joining our date?',
        ['🐶 A dog', '🐱 A cat', '🐰 A bunny', '🙅 Just us']),
    DateQuestion('pet_dream', '🐕', 'Dream pet together?',
        ['🐕 Golden retriever', '🐈 Fluffy cat', '🐢 Tortoise', '🦜 Parrot']),
    DateQuestion('pet_name', '🏷️', 'Name our future pet?',
        ['🍪 Biscuit', '🥭 Mango', '🥔 Aloo', '🌙 Luna']),
    DateQuestion('pet_dog_size', '🐕', 'Dog size?',
        ['🐩 Tiny', '🐕 Medium', '🐕‍🦺 Big', '🦮 Gentle giant']),
    DateQuestion('pet_cat_dog', '🐱', 'Cat person or dog person?',
        ['🐱 Cats', '🐶 Dogs', '💕 Both', '🐠 Fish, honestly']),
    DateQuestion('pet_unusual', '🦔', 'Unusual pet?',
        ['🦔 Hedgehog', '🦎 Gecko', '🐹 Hamster', '🐌 Snail']),
    DateQuestion('pet_date_activity', '🐕', 'Pet-friendly date?',
        ['🌳 Dog park', '☕ Pet café', '🥾 Trail walk', '🏖️ Dog beach']),
    DateQuestion('pet_wild_animal', '🦒', 'Wild animal to see together?',
        ['🐘 Elephants', '🐅 Tiger safari', '🐬 Dolphins', '🦩 Flamingos']),
    DateQuestion('pet_spirit', '🦊', 'Our couple spirit animal?',
        ['🦦 Otters', '🐧 Penguins', '🦊 Foxes', '🐼 Pandas']),
    DateQuestion('pet_farm', '🐄', 'Favorite farm animal?',
        ['🐐 Goat', '🐑 Sheep', '🐓 Rooster', '🐴 Pony']),
    DateQuestion('pet_cuddle', '🧸', 'Baby animal to cuddle?',
        ['🐶 Puppy', '🐱 Kitten', '🐣 Chick', '🐨 Koala']),
    DateQuestion('pet_costume', '🎃', 'Pet costume?',
        ['🦸 Superhero', '🦖 Dinosaur', '🍕 Pizza slice', '🎀 Bow tie only']),
    DateQuestion('pet_fish_name', '🐟', 'If we got a goldfish…', [
      '🐟 Name it Nemo',
      '🫧 Name it Bubbles',
      '👑 Name it Sir Swims',
      '🎲 Random name'
    ]),
    DateQuestion('pet_feed_stray', '🐕', 'We see a stray pup. We…', [
      '🍪 Feed it',
      '📸 Photo first',
      '🏠 Take it home',
      '📞 Call a shelter'
    ]),
    DateQuestion('pet_bird_call', '🐦', 'Bird to wake us up?', [
      '🦜 Parrot chatter',
      '🐦 Sparrow chirps',
      '🐓 Rooster crow',
      '🦉 Owl hoot'
    ]),
    DateQuestion('pet_ocean', '🐳', 'Ocean friend?',
        ['🐳 Whale', '🐙 Octopus', '🐢 Sea turtle', '🦭 Seal']),
    DateQuestion('pet_bug', '🦋', 'Favorite little critter?',
        ['🦋 Butterfly', '🐞 Ladybug', '🐝 Bee', '🐌 Snail']),
    DateQuestion('vibe_cozy_adventure', '🔥', 'Cozy or adventurous?',
        ['🛋️ Cozy', '🧗 Adventurous', '🔀 Cozy adventure', '🎲 Surprise']),
    DateQuestion('vibe_date_energy', '⚡', 'Date energy?',
        ['😌 Calm', '🤪 Chaotic', '💕 Romantic', '🎉 Party']),
    DateQuestion('vibe_homebody', '🏠', 'Homebody or explorer?',
        ['🏠 Homebody', '🧭 Explorer', '🔀 Both', '🎲 Depends on day']),
    DateQuestion('vibe_introvert', '🤫', 'Crowd level?',
        ['🤫 Just us', '👥 Small group', '🎉 Big party', '🏟️ Packed stadium']),
    DateQuestion('vibe_spontaneous', '🎲', 'Spontaneous plan?', [
      '🚗 Random road trip',
      '🎟️ Last-minute show',
      '🍜 New restaurant',
      '🗺️ Get lost on purpose'
    ]),
    DateQuestion('vibe_cozy_night', '🕯️', 'Cozy night essentials?',
        ['🕯️ Candles', '🧦 Fuzzy socks', '🍵 Warm drink', '🎬 Old movie']),
    DateQuestion('vibe_thrill', '🎢', 'Thrill level?',
        ['🧸 None', '🎢 Roller coasters', '🏚️ Haunted house', '🪂 Skydiving']),
    DateQuestion('vibe_aesthetic', '✨', 'Date aesthetic?',
        ['🌿 Cottagecore', '🌃 City neon', '📼 Retro', '🏖️ Beachy']),
    DateQuestion('vibe_mood_lighting', '💡', 'Lighting mood?', [
      '🕯️ Candlelight',
      '✨ Fairy lights',
      '🌅 Natural sunlight',
      '🌈 Neon'
    ]),
    DateQuestion('vibe_scent', '🕯️', 'Candle scent?',
        ['🍦 Vanilla', '🌹 Rose', '🌲 Pine', '☕ Coffee']),
    DateQuestion('vibe_blanket', '🛏️', 'Blanket burrito?', [
      '🌯 One big blanket',
      '🛏️ Two blankets',
      '🔥 Too hot',
      '🧸 Plus stuffed toys'
    ]),
    DateQuestion('vibe_fireplace', '🔥', 'By a fire, we…', [
      '🍡 Roast marshmallows',
      '🎸 Play guitar',
      '👻 Tell stories',
      '😴 Doze off'
    ]),
    DateQuestion('vibe_fast_slow', '🐢', 'Pace of our date?',
        ['🐢 Slow & dreamy', '🚶 Easy stroll', '🏃 Fast & packed', '🔀 Mix']),
    DateQuestion('vibe_quiet_loud', '🔊', 'Quiet place or lively place?',
        ['🤫 Quiet', '🎶 Lively', '🔀 Quiet, then loud', "🎲 Whatever's open"]),
    DateQuestion('vibe_glam_simple', '💫', 'Glam or simple?',
        ['💫 Glam', '🌼 Simple', '🎨 Quirky', '🧢 Sporty']),
    DateQuestion('vibe_old_new', '🕰️', 'Old-school or modern date?', [
      '📜 Old-school letters',
      '📱 Modern apps',
      '📼 Retro theme',
      '🤖 Futuristic'
    ]),
    DateQuestion('vibe_city_nature', '🏙️', 'City or nature?',
        ['🏙️ City', '🌲 Nature', '🏘️ Small town', '🏝️ Island']),
    DateQuestion('vibe_risk', '🎯', 'Try something neither of us has done?',
        ['🙋 Yes!', '🤔 Maybe', '🙅 Stick to safe', '🎲 Flip a coin']),
    DateQuestion('vibe_sweet_spicy', '💞', 'Our date personality?',
        ['🍬 Sweet', '🌶️ Spicy', '🍋 Zesty', '🍯 Warm']),
    DateQuestion('vibe_planner_flow', '🧭', 'Who keeps the date on track?', [
      '📋 The planner',
      '🌊 The go-with-flow',
      '⏰ A phone alarm',
      '🙅 Nobody'
    ]),
    DateQuestion('budget_level', '💰', 'Budget for our date?', [
      '🆓 Free fun',
      '💸 Budget-friendly',
      '💳 Treat ourselves',
      '💎 Splurge'
    ]),
    DateQuestion('budget_who_pays', '🧾', 'Who pays on the first date?', [
      '🤝 Split it',
      '🔁 Take turns',
      '🙋 Whoever asked',
      '🎲 Rock-paper-scissors'
    ]),
    DateQuestion('budget_free_date', '🆓', 'Best free date?', [
      '🌳 Park picnic',
      '🏛️ Free museum day',
      '🌅 Sunset walk',
      '🎮 Game night at home'
    ]),
    DateQuestion('budget_cheap_eats', '🪙', 'Cheap-eats crawl?', [
      '🌮 Street food',
      '🍜 Noodle bar',
      '🥟 Momo stall',
      '🍦 Ice cream cart'
    ]),
    DateQuestion('budget_treat', '🎟️', "If we splurge, it's on…",
        ['🍽️ Fancy dinner', '🎤 Concert', '✈️ A trip', '🛍️ Shopping']),
    DateQuestion('budget_save', '🐷', 'Saving for a dream?',
        ['✈️ Trip abroad', '🎸 Instrument', '🐶 Pet supplies', '🎮 Console']),
    DateQuestion('budget_tip', '💵', 'Leaving a tip?', [
      '💯 Always generous',
      '🙂 Standard',
      '🍬 Plus a sweet note',
      '🙏 Big thank-you'
    ]),
    DateQuestion('budget_bill_game', '🃏', 'Bill game?', [
      '🃏 Card roulette',
      '✂️ Rock-paper-scissors',
      '🪙 Coin flip',
      '🧮 Exact split'
    ]),
    DateQuestion('budget_coupon', '🏷️', 'Use a coupon on a date?',
        ['💯 Yes, smart', '🫣 Secretly', '🙅 Never', '🎉 Proudly']),
    DateQuestion('budget_100', '💸', '₹500 / \$10 date challenge?', [
      '🌮 Street food',
      '🎬 Cheap matinee',
      '☕ Two coffees + walk',
      '🧺 Picnic supplies'
    ]),
    DateQuestion('budget_splurge_meal', '🍽️', 'Fanciest meal ever?', [
      '🍣 Omakase',
      '🥩 Steakhouse',
      '🍛 Royal thali',
      '🦞 Seafood platter'
    ]),
    DateQuestion('budget_cash_card', '💳', 'Paying with?',
        ['💵 Cash', '💳 Card', '📱 UPI / phone', '🍪 IOU cookies']),
    DateQuestion('budget_free_fun', '🎈', 'Zero-money fun?', [
      '🎤 Karaoke at home',
      '🌌 Stargazing',
      '🚶 Window shopping',
      '📚 Library visit'
    ]),
    DateQuestion('fest_diwali', '🪔', 'Diwali together?', [
      '🪔 Light diyas',
      '🍬 Sweets exchange',
      '🎆 Watch fireworks',
      '🎨 Make rangoli'
    ]),
    DateQuestion('fest_holi', '🎨', 'Holi plan?', [
      '🎨 Colors all day',
      '💦 Water balloons',
      '🥛 Thandai',
      '📸 Watch & photos'
    ]),
    DateQuestion('fest_christmas', '🎄', 'Christmas date?', [
      '🎄 Decorate a tree',
      '🍪 Bake cookies',
      '🎅 Secret Santa',
      '⛸️ Ice rink'
    ]),
    DateQuestion('fest_valentine', '💘', "Valentine's Day?", [
      '🍽️ Fancy dinner',
      '🏠 Cozy home',
      '🙅 Skip the hype',
      '🎁 Surprise day'
    ]),
    DateQuestion('fest_halloween', '🎃', 'Halloween night?', [
      '🏚️ Haunted house',
      '🎃 Carve pumpkins',
      '🧛 Costume party',
      '🎬 Horror movies'
    ]),
    DateQuestion('fest_new_year_res', '📝', 'New Year resolution together?', [
      '🏃 Get fit',
      '✈️ Travel more',
      '🍳 Cook more',
      '📵 Less screen time'
    ]),
    DateQuestion('fest_navratri', '💃', 'Navratri night?',
        ['💃 Garba', '🥁 Dandiya', '🍲 Festive food', '📸 Outfit photos']),
    DateQuestion('fest_eid', '🌙', 'Eid festivities?', [
      '🍲 Biryani feast',
      '🍮 Sheer khurma',
      '🛍️ Night market',
      '🎁 Eidi gifts'
    ]),
    DateQuestion('fest_onam_pongal', '🌾', 'Harvest festival treat?', [
      '🍌 Onam sadhya',
      '🍚 Pongal',
      '🌾 Lohri bonfire',
      '🪁 Sankranti kites'
    ]),
    DateQuestion('fest_lunar', '🏮', 'Lunar New Year?', [
      '🏮 Lantern walk',
      '🥟 Dumpling night',
      '🐉 Dragon dance',
      '🧧 Red envelopes'
    ]),
    DateQuestion('fest_birthday', '🎂', 'Your birthday date?', [
      '🎉 Big party',
      '🍽️ Intimate dinner',
      '🎢 Adventure day',
      '🛌 Breakfast in bed'
    ]),
    DateQuestion('fest_spring', '🌸', 'Spring date?', [
      '🌸 Blossom picnic',
      '🚲 Bike ride',
      '🌷 Flower show',
      '🪁 Kite flying'
    ]),
    DateQuestion('fest_summer', '☀️', 'Summer date?',
        ['🏖️ Beach', '🍉 Fruit picnic', '🏊 Pool day', '🍦 Ice cream crawl']),
    DateQuestion('fest_autumn', '🍂', 'Autumn date?', [
      '🍂 Leaf walk',
      '🎃 Pumpkin patch',
      '☕ Spiced drinks',
      '🧥 Sweater shopping'
    ]),
    DateQuestion('fest_winter', '❄️', 'Winter date?',
        ['⛸️ Ice skating', '🔥 Bonfire', '🍲 Hot soup', '🎄 Lights walk']),
    DateQuestion('fest_fireworks', '🎆', 'Watching fireworks from…',
        ['🏙️ Rooftop', '🏖️ Beach', '🚗 Car', '🪟 Bedroom window']),
    DateQuestion('fest_fair', '🎡', 'Festival fair pick?',
        ['🎡 Rides', '🍭 Sweets', '🛍️ Stalls', '🎶 Live music']),
    DateQuestion('fest_carnival', '🎭', 'Carnival costume?',
        ['🎭 Masks', '🪶 Feathers', '🌈 Glitter', '🤡 Clown']),
    DateQuestion('fest_food_festival', '🍢', 'Food festival strategy?', [
      '🔁 Try everything',
      '🌶️ Spicy only',
      '🍰 Sweets only',
      '🗺️ One per country'
    ]),
    DateQuestion('fest_book_fair', '📚', 'Book fair haul?', [
      '📚 Ten books',
      '📖 One perfect book',
      '🔖 Bookmarks',
      '☕ Café break'
    ]),
    DateQuestion('fest_music_fest', '🎪', 'Festival camping?',
        ['⛺ Tent', '🚐 Van', '🏨 Hotel nearby', '🏠 Go home nightly']),
    DateQuestion('fest_mothers_day', '💐', 'Planning a surprise for a parent?',
        ['🍳 Cook a meal', '💐 Flowers', '🎥 Video montage', '🎁 Spa voucher']),
    DateQuestion('fest_friendship_day', '🤝', 'Friendship Day?', [
      '📿 Bracelets',
      '🍕 Group party',
      '📸 Throwback photos',
      '💌 Letters'
    ]),
    DateQuestion('fest_raksha_alt', '🎁', 'Festival gift exchange?',
        ['🍬 Sweets', '🎁 Small gifts', '💸 Envelopes', '💌 Cards']),
    DateQuestion('fest_rainy_season', '🌧️', 'Monsoon festival vibe?', [
      '🌿 Teej swings',
      '🌊 Beach in rain',
      '🍲 Monsoon menu',
      '☔ Rain walk'
    ]),
    DateQuestion('fest_hometown', '🏠', 'Hometown festival together?', [
      '🎉 Your hometown',
      '🎊 My hometown',
      '🌍 A new place',
      '🏙️ Our city'
    ]),
    DateQuestion('fest_lantern', '🏮', 'Floating lanterns?', [
      '🏮 Sky lanterns',
      '🕯️ River diyas',
      '✨ Fairy lights',
      '🎐 Paper lanterns'
    ]),
    DateQuestion('fest_decor', '🎊', 'Decorating together?',
        ['✨ Fairy lights', '🌸 Flowers', '🎈 Balloons', '🪔 Diyas']),
    DateQuestion('fest_countdown', '⏱️', 'At the countdown, we…',
        ['🤗 Hug', '🎆 Shout & cheer', '📸 Selfie', '🎶 Sing']),
    DateQuestion(
        'hypo_movie_genre',
        '🎞️',
        "If our love story were a film, it'd be…",
        ['💕 Rom-com', '🎶 Musical', '🧭 Road movie', '👽 Sci-fi romance']),
    DateQuestion('hypo_superpower', '🦸', 'Shared superpower for a day?', [
      '✈️ Teleport anywhere',
      '⏸️ Freeze time',
      '🫥 Invisibility',
      '🗣️ Talk to animals'
    ]),
    DateQuestion('hypo_time_travel', '⏳', 'Time-travel date to…', [
      '🦖 Dinosaur era',
      '🏰 Medieval fair',
      '🕺 1970s disco',
      '🚀 Year 3000'
    ]),
    DateQuestion('hypo_island', '🏝️', "Stranded on an island, we'd bring…",
        ['🔪 A knife', '🎸 A guitar', '📚 A book', '🍫 Snacks']),
    DateQuestion('hypo_lottery', '💰', 'We win the lottery. First thing?', [
      '✈️ World trip',
      '🏡 Dream house',
      '🎁 Gifts for family',
      '🐶 Animal shelter'
    ]),
    DateQuestion('hypo_zombie', '🧟', 'Zombie apocalypse role?', [
      '🗺️ The planner',
      '🏹 The fighter',
      '🍳 The cook',
      '🏃 The fast runner'
    ]),
    DateQuestion('hypo_dinner_guest', '🍽️', 'Dream dinner guest for us?',
        ['🎤 A pop star', '🧪 A scientist', '😂 A comedian', '🏏 A cricketer']),
    DateQuestion('hypo_fictional', '📚', 'Fictional world to live in?',
        ['🧙 Hogwarts', '🐉 Westeros', '🧚 Neverland', "🍫 Wonka's factory"]),
    DateQuestion('hypo_animal_swap', '🐾', 'If we became animals for a day…',
        ['🦅 Eagles', '🐬 Dolphins', '🐱 Cats', '🐼 Pandas']),
    DateQuestion('hypo_famous_couple', '💑', "Famous duo we'd be?", [
      '🧙 Ron & Hermione',
      '🐻 Baloo & Mowgli',
      '🍞 Bread & butter',
      '🐭 Tom & Jerry'
    ]),
    DateQuestion('hypo_job_swap', '💼', 'Swap lives for a day?',
        ['🙋 Yes', '🙅 No way', '😂 Only for fun', '🤔 Just the weekend']),
    DateQuestion('hypo_cooking_show', '🍳', 'If we hosted a cooking show…', [
      '🔥 Fire & spice',
      '🍰 Sweet treats',
      '🥫 Budget meals',
      '💥 Kitchen disasters'
    ]),
    DateQuestion('hypo_band_name', '🎸', 'Our band name?', [
      '🌙 Midnight Chai',
      '🍕 Pizza Hearts',
      '🦋 Paper Moths',
      '🔥 Velvet Thunder'
    ]),
    DateQuestion('hypo_mascot', '🧸', 'Our couple mascot?',
        ['🐧 Penguin', '🦥 Sloth', '🦄 Unicorn', '🥔 Potato']),
    DateQuestion('hypo_house', '🏡', 'Dream house?',
        ['🏡 Cottage', '🏙️ City loft', '🏖️ Beach house', '🌲 Forest cabin']),
    DateQuestion('hypo_one_city', '🌆', 'Live in one city forever?',
        ['🗼 Paris', '🌊 Mumbai', '🏯 Tokyo', '🍁 Vancouver']),
    DateQuestion('hypo_no_phones', '📵', 'A week with no phones?',
        ['😌 Bliss', '😰 Panic', '📸 Need a camera', '📖 Lots of books']),
    DateQuestion('hypo_robot', '🤖', 'Our robot butler does…',
        ['🍳 Cooking', '🧹 Cleaning', '💆 Massages', '🎤 Jokes']),
    DateQuestion('hypo_magic_door', '🚪', 'A magic door opens to…',
        ['🏖️ A beach', '🏰 A castle', '🌌 Space', '🍬 Candyland']),
    DateQuestion('hypo_reality_show', '📺', 'Our reality show title?', [
      '💕 Love & Chai',
      '🧳 Lost Together',
      '🍳 Kitchen Chaos',
      '🎲 Random Adventures'
    ]),
    DateQuestion('hypo_drive_anywhere', '🗺️', 'Full tank, open road. Head…', [
      '⛰️ To the hills',
      '🌊 To the coast',
      '🏜️ Into the desert',
      '🎲 Wherever'
    ]),
    DateQuestion('hypo_genie', '🧞', "Genie's one wish for us?", [
      '🌍 Travel forever',
      '🍕 Endless food',
      '⏳ More time together',
      '🐶 Many pets'
    ]),
    DateQuestion('hypo_age_swap', '👴', 'Our cute old-age hobby?', [
      '🌿 Gardening',
      '💃 Dance classes',
      '♟️ Chess in park',
      '🧶 Knitting'
    ]),
    DateQuestion('hypo_book_title', '📖', 'Title of our date memoir?', [
      '☕ Coffee & Chaos',
      '🌙 Two Night Owls',
      '🗺️ Lost & Found',
      '🍜 Noodles Forever'
    ]),
    DateQuestion('hypo_restaurant', '🍽️', 'If we opened a café…',
        ['☕ Book café', '🍕 Pizza joint', '🫖 Chai bar', '🍰 Dessert parlor']),
    DateQuestion('hypo_vacation_planet', '🪐', 'Vacation on another planet?',
        ['🔴 Mars', '🪐 Saturn rings', '🌕 The Moon', '🌌 Unknown galaxy']),
    DateQuestion('hypo_rewind', '⏪', 'Rewind one moment of our date?',
        ['👋 First hello', '😂 First laugh', '🍰 First bite', '🌙 Goodbye']),
    DateQuestion('hypo_soundtrack_life', '🎧', 'Background music for our life?',
        ['🎻 Orchestral', '🎸 Indie', '🎶 Bollywood', '🎮 Video game tunes']),
    DateQuestion('hypo_famous_for', '🌟', 'We become famous for…',
        ['🍳 Cooking', '😂 Comedy', '💃 Dancing', '🧳 Travel vlogs']),
    DateQuestion('hypo_teleport_meal', '🍜', 'Teleport for one meal to…', [
      '🍜 Tokyo ramen',
      '🍕 Naples pizza',
      '🍛 Hyderabad biryani',
      '🥐 Paris café'
    ]),
    DateQuestion('hypo_shrink', '🐜', 'If we shrank to ant size…', [
      '🍃 Ride a leaf',
      '🍪 Feast on crumbs',
      '🐞 Befriend a ladybug',
      '🏃 Run home'
    ]),
    DateQuestion('hypo_invisible_day', '🫥', "Invisible for a day, we'd…", [
      '🎬 Visit a film set',
      '🍰 Taste bakery cakes',
      '🎤 Go backstage',
      '😂 Prank friends'
    ]),
    DateQuestion('hypo_holiday_invent', '🎉', 'Invent a holiday for…',
        ['🍕 Pizza Day', '😴 Nap Day', '🐶 Pet Day', '💌 Letter Day']),
    DateQuestion('hypo_alien', '👽', 'An alien visits. We show them…',
        ['🍛 Our food', '🎶 Our music', '🏏 Cricket', '🐱 Cats']),
    DateQuestion('hypo_mermaid', '🧜', 'Underwater city date?', [
      '🐠 Coral café',
      '🐙 Octopus concert',
      '🐢 Turtle taxi',
      '🦈 Shark-free zone'
    ]),
    DateQuestion('hypo_dragon', '🐉', "Our pet dragon's name?",
        ['🔥 Blaze', '🍡 Mochi', '🌙 Nova', '🥟 Dumpling']),
    DateQuestion('hypo_cartoon', '🖍️', 'Cartoon version of us?',
        ['🎌 Anime', '🐭 Classic Disney', '🟨 Simpsons-style', '🧱 Lego']),
    DateQuestion('hypo_villain', '😈', 'If we were movie villains…', [
      '🕵️ Master thieves',
      '🧪 Mad scientists',
      '🍰 Cake stealers',
      '😼 Cat cartel'
    ]),
    DateQuestion('hypo_fortune', '🔮', 'Fortune teller says…', [
      '💍 Big adventure',
      '🍕 Lots of pizza',
      '🐶 A dog soon',
      '😂 Endless laughs'
    ]),
    DateQuestion('hypo_rain_food', '🌧️', 'It rains food. What falls?',
        ['🍕 Pizza', '🍬 Candy', '🥟 Momos', '🍩 Donuts']),
    DateQuestion('hypo_eternal_season', '🌍', 'Live in one season forever?',
        ['🌸 Spring', '☀️ Summer', '🍂 Autumn', '❄️ Winter']),
    DateQuestion('hypo_decade', '📻', 'Date in which decade?',
        ['🎷 1920s', '📻 1960s', '📼 1980s', '💿 2000s']),
    DateQuestion('hypo_kingdom', '👑', 'Rulers of a tiny kingdom. First law?', [
      '🍕 Free pizza Fridays',
      '😴 Nap breaks',
      '🐶 Pets everywhere',
      '🎶 Dance Mondays'
    ]),
    DateQuestion('hypo_one_app', '📱', 'Keep only one app?',
        ['💬 Messaging', '🗺️ Maps', '🎵 Music', '📸 Camera']),
    DateQuestion('hypo_body_swap', '🔄', 'Body swap for a day: first thing?', [
      '😂 Laugh in mirror',
      '📱 Read own chats',
      '🍳 Cook their fave',
      '🙈 Hide inside'
    ]),
    DateQuestion('hypo_famous_painting', '🖼️', 'Step into a painting?', [
      '🌌 Starry Night',
      '🪷 Water Lilies',
      '🌊 The Great Wave',
      "🎨 Mona Lisa's room"
    ]),
    DateQuestion('hypo_new_language', '🗣️', 'Invent a secret language using…',
        ['😊 Emojis', '👋 Hand signs', '🎵 Whistles', '🔤 Backwards words']),
    DateQuestion('hypo_flavor', '🍦', 'If we were an ice cream flavor…', [
      '🍓 Strawberry swirl',
      '🍫 Rocky road',
      '🥭 Mango sorbet',
      '🧂 Salted caramel'
    ]),
    DateQuestion('hypo_weather_us', '🌦️', 'If our vibe were weather…',
        ['☀️ Sunshine', '🌧️ Cozy rain', '⛈️ Thunderstorm', '🌈 Rainbow']),
    DateQuestion('hypo_cars', '🚗', 'If we were a car…', [
      '🏎️ Sports car',
      '🚐 Camper van',
      '🛺 Auto rickshaw',
      '🚙 Reliable hatchback'
    ]),
    DateQuestion('hypo_dessert_us', '🍰', 'If we were a dessert…',
        ['🍮 Gulab jamun', '🧁 Cupcake', '🍫 Brownie', '🍨 Sundae']),
    DateQuestion(
        'hypo_ten_years', '🔟', 'Ten years from now, our date night is…', [
      '🍽️ Same café',
      '✈️ New country',
      '🛋️ Couch & pizza',
      '🏕️ Camping trip'
    ]),
    DateQuestion('hypo_secret_agent', '🕵️', 'Secret agents: our cover?',
        ['🍰 Bakery owners', '🎨 Painters', '🧳 Tourists', '🎻 Musicians']),
    DateQuestion('hypo_treasure', '🪙', 'Found a treasure map. We…', [
      '🗺️ Follow it now',
      '📸 Post it',
      '🏛️ Give to museum',
      '🙈 Frame it'
    ]),
    DateQuestion('hypo_game_char', '🎮', 'If we were game characters…', [
      '🍄 Mario & Luigi',
      '🦔 Sonic & Tails',
      '🧝 Zelda heroes',
      '🐸 Frogger duo'
    ]),
    DateQuestion('hypo_movie_scene', '🎬', 'Recreate a movie scene?', [
      '🚢 Titanic bow',
      '🌧️ Rain dance',
      '🍝 Spaghetti scene',
      '🏃 Airport run'
    ]),
    DateQuestion('hypo_lost_phone', '📱', 'Phone dies mid-date?', [
      '😌 Better date',
      '🗺️ Get lost',
      '📝 Use paper map',
      '🙋 Ask strangers'
    ]),
    DateQuestion('hypo_magic_school', '🪄', 'Magic school subject?',
        ['🧪 Potions', '🧹 Flying', '🐉 Creature care', '🔮 Divination']),
    DateQuestion('hypo_plant_us', '🌻', 'If we were plants…',
        ['🌻 Sunflowers', '🌵 Cacti', '🌹 Roses', '🪴 Money plants']),
    DateQuestion('hypo_world_record', '🏅', 'World record attempt?', [
      '🍕 Most pizza eaten',
      '💃 Longest dance',
      '🤗 Longest hug',
      '🎤 Most songs sung'
    ]),
    DateQuestion('hypo_bakery_name', '🧁', 'Name our bakery?', [
      '🧁 Crumbs & Co',
      '🍞 Rise Together',
      '🍪 Sweet Spot',
      '🥐 Butter Hearts'
    ]),
    DateQuestion('hypo_spaceship', '🚀', 'On a spaceship, we…', [
      '🪟 Stare at stars',
      '🧑‍🚀 Moonwalk',
      '🍜 Eat space food',
      '📸 Selfie with Earth'
    ]),
    DateQuestion('hypo_tiny_house', '🏠', 'Tiny house location?', [
      '🏔️ Mountain edge',
      '🏖️ Beachfront',
      '🌲 Deep forest',
      '🏙️ City rooftop'
    ]),
    DateQuestion('hypo_no_money', '🪙', "Money doesn't exist. Our date is…",
        ['🌅 A sunrise hike', '🎨 Painting', '🍳 Cooking', '🌌 Stargazing']),
    DateQuestion(
        'hypo_meet_again', '🔁', 'If we met again for the first time…', [
      '😎 Play it cool',
      '😂 Laugh a lot',
      '💬 Talk all night',
      '🙈 Be shy again'
    ]),
    DateQuestion('hypo_movie_crossover', '🍿', 'We star in a…', [
      '🦸 Superhero movie',
      '🧟 Zombie comedy',
      '🎶 Musical',
      '🔍 Detective film'
    ]),
    DateQuestion('hypo_cooking_team', '🍽️', 'Cooking contest team name?', [
      '🔥 Spice Squad',
      '🍰 Sugar Rush',
      '🥟 Dumpling Duo',
      '🍳 Pan-tastic'
    ]),
    DateQuestion('hypo_robot_pet', '🐕', 'Robot pet?',
        ['🐕 Robo-dog', '🐈 Robo-cat', '🐉 Robo-dragon', '🦖 Robo-dino']),
    DateQuestion('hypo_free_flight', '🛫', 'Free flight anywhere, leaving now?',
        ['✈️ Go now', '🧳 Pack first', '🏠 Next month', '🙅 Stay home']),
    DateQuestion('hypo_famous_landmark', '🏛️', 'Sleepover at a landmark?', [
      '🗼 Eiffel Tower',
      '🕌 Taj Mahal gardens',
      '🏛️ Colosseum',
      '🗽 Liberty Island'
    ]),
    DateQuestion('hypo_cloud_house', '☁️', 'Live on a cloud?', [
      '☁️ Yes, so soft',
      '🌧️ Too wet',
      '🪂 Bring parachutes',
      '🌈 Rainbow slide down'
    ]),
    DateQuestion('hypo_switch_skill', '🧠', 'Instantly master a skill?', [
      '🎹 Piano',
      '🗣️ All languages',
      '🍳 Chef-level cooking',
      '💃 Dancing'
    ]),
    DateQuestion('hypo_rename_us', '🏷️', 'Couple name mashup style?', [
      '🔤 First halves',
      '🔡 Last halves',
      '🍕 A food name',
      '🦸 Superhero name'
    ]),
    DateQuestion('hypo_toy', '🧸', 'If we were toys…',
        ['🧸 Teddy bears', '🪀 Yo-yos', '🧩 Puzzle pieces', '🚂 Toy trains']),
    DateQuestion('hypo_infinite_snack', '♾️', 'Infinite supply of…',
        ['🍿 Popcorn', '🫖 Chai', '🍫 Chocolate', '🥟 Momos']),
    DateQuestion(
        'hypo_tv_channel',
        '📡',
        'We get our own TV channel. It shows…',
        ['🍳 Cooking', '🐾 Pets', '🎶 Music', '😂 Bloopers']),
    DateQuestion('hypo_teleport_now', '⚡', 'Teleport right now to…',
        ['🏖️ Beach', '🏔️ Mountains', '🏠 Each other', '🍕 Pizza place']),
    DateQuestion('hypo_museum_of_us', '🏛️', 'A museum of us displays…', [
      '📸 Photos',
      '🎟️ Ticket stubs',
      '💬 Funny chats',
      '🍕 Food receipts'
    ]),
    DateQuestion('hypo_sci_fi_gadget', '🔫', 'Sci-fi gadget?',
        ['⏳ Time-turner', '📟 Translator', '🚪 Portal door', '🧲 Hoverboard']),
    DateQuestion('hypo_ghost', '👻', 'Our house has a friendly ghost. We…',
        ['👻 Name it', '🍪 Leave cookies', '🎬 Make a doc', '🏃 Move out']),
    DateQuestion('hypo_awards', '🏆', "Award we'd win as a couple?", [
      '😂 Funniest duo',
      '🍕 Biggest foodies',
      '⏰ Always late',
      '💕 Cutest couple'
    ]),
    DateQuestion('hypo_mythic', '🦄', 'Mythical creature friend?',
        ['🦄 Unicorn', '🐉 Dragon', '🧚 Fairy', '🦅 Phoenix']),
    DateQuestion('pref_text_before', '📱', 'Text before the date?', [
      '💬 Lots of hype',
      '👋 Quick hi',
      '📍 Just location',
      '🤐 Save it for later'
    ]),
    DateQuestion('pref_greeting', '👋', 'How do we greet?',
        ['🤗 Hug', '👋 Wave', '🤝 Handshake', '🙏 Namaste']),
    DateQuestion('pref_seat', '🪑', 'Sit across or side by side?',
        ['🔄 Across', '↔️ Side by side', '🛋️ Couch cuddle', '🪑 Bar stools']),
    DateQuestion('pref_photos_date', '📸', 'Photos during the date?',
        ['🤳 Lots', '📸 Just one', '🙅 None', '🎞️ Film camera only']),
    DateQuestion('pref_phone_rule', '📵', 'Phone rule on our date?', [
      '📵 Phones away',
      '🤳 Photos only',
      '📲 Normal use',
      '🎮 Phone games together'
    ]),
    DateQuestion(
        'pref_meet_where', '📍', 'Meet at the place or travel together?', [
      '📍 Meet there',
      '🚗 Pick-up',
      '🚇 Meet at metro',
      '🎲 Surprise spot'
    ]),
    DateQuestion('pref_planner', '📋', 'Who plans the date?',
        ['🙋 Me', '👉 You', '🤝 Both', '🎲 Random app']),
    DateQuestion('pref_hand_holding', '🤝', 'Holding hands?', [
      '💕 Right away',
      '⏳ Later on',
      '🤭 Pinky only',
      '🙂 When it feels right'
    ]),
    DateQuestion('pref_order_for', '🍽️', 'Ordering food for each other?',
        ['💯 Fun!', '🤔 Risky', "🙅 I'll pick mine", '🎲 Only dessert']),
    DateQuestion('pref_small_talk', '💬', 'Small talk or straight to deep?', [
      '☁️ Small talk first',
      '🌊 Straight deep',
      '😂 Jokes first',
      '🎲 Wherever it goes'
    ]),
    DateQuestion('pref_laughs', '😂', 'What makes us laugh most?',
        ['🤪 Silly puns', '🐶 Animal videos', '😏 Witty banter', '🤦 Fails']),
    DateQuestion('pref_surprises', '🎉', 'Surprises on a date?',
        ['🥰 Love them', '😅 Small ones', '📋 Prefer plans', '🎲 Depends']),
    DateQuestion('pref_sweet_gesture', '💝', 'Sweetest small gesture?', [
      '🧥 Offering a jacket',
      '🍫 Saving the last bite',
      '💐 One flower',
      '🎧 Sharing earbuds'
    ]),
    DateQuestion('pref_pda', '💑', 'Cute public gestures?', [
      '🤝 Holding hands',
      '🤗 Quick hugs',
      '😊 Just smiles',
      '🙈 Keep it private'
    ]),
    DateQuestion('pref_drink_order', '☕', 'Who orders the drinks?',
        ['🙋 Me', '👉 You', '🤝 Together', '📱 Order on app']),
    DateQuestion('pref_split_dessert', '🍰', 'Last bite of dessert goes to…',
        ['🙋 Me', '👉 You', '✂️ Split it', '🪙 Coin toss']),
    DateQuestion('pref_compliment_style', '💬', 'Compliment style?', [
      '💐 Sweet & direct',
      '😏 Playful tease',
      '📝 In a note',
      '😳 Too shy'
    ]),
    DateQuestion('pref_window_seat', '🪟', 'Restaurant table?', [
      '🪟 Window',
      '🕯️ Cozy corner',
      '🌳 Outdoor patio',
      '🍳 Kitchen counter'
    ]),
    DateQuestion('pref_walk_side', '🚶', 'Walking together we…', [
      '🤝 Hold hands',
      '🙌 Swing arms',
      '📸 Stop for photos',
      '🏃 Race each other'
    ]),
    DateQuestion('pref_music_date', '🎶', 'Background music at dinner?', [
      '🎻 Soft jazz',
      '🎶 Bollywood unplugged',
      '🔇 None',
      '🎧 Our playlist'
    ]),
    DateQuestion('pref_cute_or_funny', '😊', 'Date should be…',
        ['😊 Cute', '😂 Funny', '🌹 Romantic', '🤪 Weird']),
    DateQuestion('pref_nickname', '🏷️', 'Nickname for each other?', [
      '🍯 Something sweet',
      '🦖 Something silly',
      '🍕 A food',
      '🙅 Real names'
    ]),
    DateQuestion('pref_late_reply', '⏰', 'Late reply rule?', [
      '😌 No stress',
      '🙃 Tiny sulk',
      '📞 Just call',
      '🎙️ Send voice note'
    ]),
    DateQuestion('pref_selfie_angle', '🤳', 'Who takes the selfie?',
        ['🙋 Me', '👉 You', '🙋 Ask a stranger', '⏲️ Timer on a wall']),
    DateQuestion('pref_rain_check', '📅', 'Postponing a date?', [
      '📅 Reschedule fast',
      '🎥 Video call instead',
      '🍕 Send food',
      '😢 Sad but OK'
    ]),
    DateQuestion('pref_sharing_fries', '🍟', 'Stealing fries?', [
      '😋 Allowed',
      '🙅 Order your own',
      '🤝 Shared plate',
      '🍟 Extra large order'
    ]),
    DateQuestion('pref_menu_reading', '📖', 'Reading the menu?', [
      '📖 Every page',
      '👀 Skim fast',
      '🙋 Ask for best dish',
      '🔁 Same as you'
    ]),
    DateQuestion('pref_scent_note', '🌸', 'Smell on a date?',
        ['🌸 Perfume', '🧼 Fresh soap', '🌲 Woody', '☕ Coffee lol']),
    DateQuestion('pref_kind_gesture', '🌱', 'Kind thing to do together?', [
      '🐕 Feed a stray',
      '💸 Big tip',
      '🌳 Plant a tree',
      '🗑️ Pick up litter'
    ]),
    DateQuestion('pref_open_door', '🚪', 'Holding doors?', [
      "🚪 Whoever's first",
      '🙋 I always do',
      '👉 You always do',
      '🤝 Race for it'
    ]),
    DateQuestion('pref_left_right', '↔️', 'Bed side preference?',
        ['⬅️ Left side', '➡️ Right side', '🔀 Middle hogger', "🛌 Don't care"]),
    DateQuestion('pref_temperature', '🌡️', 'Room temperature?',
        ['🥶 Cold AC', '😊 Just right', '🥵 Warm & toasty', '🪟 Windows open']),
    DateQuestion('pref_morning_night', '🌗', 'Morning person or night owl?',
        ['🌅 Morning', '🦉 Night owl', '😴 Always sleepy', '🔀 Depends']),
    DateQuestion('pref_spoiler', '🤐', 'Spoilers?', [
      '🙅 Never',
      "🤷 Don't mind",
      '📖 Read endings first',
      '😈 I spoil on purpose'
    ]),
    DateQuestion('plan_b_rain', '☔', 'Plan B if it rains?',
        ['🎬 Movie', '☕ Café', '🏠 Home cooking', '💃 Dance anyway']),
    DateQuestion('plan_b_closed', '🚫', 'Restaurant is closed. Now?',
        ['🍜 Next door', '🌮 Street food', '📱 Order in', '🍳 Cook together']),
    DateQuestion('plan_b_late', '⏰', 'One of us is late. The other…', [
      '☕ Orders a coffee',
      '📖 Reads a book',
      '📱 Scrolls memes',
      '🎶 Listens to music'
    ]),
    DateQuestion('plan_b_lost', '🗺️', 'We take a wrong turn. We…', [
      '🎲 Explore anyway',
      '🗺️ Check the map',
      '🙋 Ask someone',
      '😂 Laugh and walk'
    ]),
    DateQuestion('plan_b_bored', '🥱', 'If the plan gets boring…',
        ['🎲 Random new plan', '🍦 Ice cream', '🎤 Karaoke', '🚶 Walk & talk']),
    DateQuestion('plan_b_sold_out', '🎟️', 'Concert sold out?', [
      '🎵 Street musicians',
      '🎧 Listen in the car',
      '🎤 Karaoke bar',
      '🍽️ Dinner instead'
    ]),
    DateQuestion('plan_b_power_cut', '🕯️', 'Power cut at home?', [
      '🕯️ Candles & stories',
      '🌌 Rooftop stars',
      '🎸 Unplugged songs',
      '🔦 Shadow puppets'
    ]),
    DateQuestion('plan_b_spill', '☕', 'Someone spills a drink. We…', [
      '😂 Laugh it off',
      '🧻 Napkin rescue',
      '📸 Photo for memories',
      '🛍️ Buy a new tee'
    ]),
    DateQuestion('plan_b_traffic', '🚦', 'Stuck in traffic for an hour?',
        ['🎶 Car karaoke', '🍿 Snack picnic', '💬 Deep talks', '🎲 Car games']),
    DateQuestion('plan_b_cancel', '🤒', 'One of us gets sick?', [
      '🍲 Soup delivery',
      '🎥 Video date',
      '🎬 Watch-party',
      '💌 Get-well notes'
    ]),
    DateQuestion('plan_b_flat_tyre', '🛞', 'Flat tyre on a road trip?', [
      '🛠️ Fix it together',
      '📞 Call for help',
      '🍵 Dhaba chai break',
      '📸 Roadside photoshoot'
    ]),
    DateQuestion('plan_b_bad_food', '🤢', 'The food is awful. We…', [
      '😂 Rate it dramatically',
      '🍕 Second dinner',
      '🤐 Eat politely',
      '🍦 Dessert fixes all'
    ]),
    DateQuestion('plan_b_crowd', '👥', 'Place is too crowded?', [
      '🚶 Leave & wander',
      '🎧 Ignore the crowd',
      '🍦 Grab & go',
      '🏠 Go home'
    ]),
    DateQuestion('plan_b_awkward', '😅', 'Awkward silence?', [
      '❓ Ask a fun question',
      '😂 Tell a joke',
      '🎶 Play a song',
      '🙂 Just smile'
    ]),
    DateQuestion('plan_b_no_table', '🪑', 'No table for an hour?', [
      '🚶 Walk nearby',
      '🌮 Street snack first',
      '🍽️ Try another place',
      '🧺 Takeaway picnic'
    ]),
    DateQuestion('end_how', '🌙', 'How should our date end?', [
      '🌙 Walk under the stars',
      '🍦 Ice cream stop',
      '🚗 Long drive home',
      '👋 Sweet goodbye'
    ]),
    DateQuestion('end_goodbye', '👋', 'Goodbye style?', [
      '🤗 Big hug',
      '👋 Wave & smile',
      '💌 Text right after',
      '🎶 One last song'
    ]),
    DateQuestion('end_last_stop', '🍨', 'Last stop of the night?', [
      '🍨 Dessert place',
      '☕ Chai stall',
      '🌃 Viewpoint',
      '🚶 Doorstep walk'
    ]),
    DateQuestion('end_message', '📱', 'After-date text?', [
      '🥰 "Had so much fun!"',
      '📸 Send photos',
      '🎵 Send a song',
      '😴 "Home safe"'
    ]),
    DateQuestion('end_drop_off', '🚕', 'Getting home safe?', [
      '🚕 Separate cabs',
      '🚶 Walk together',
      '📍 Share live location',
      '🚇 Ride the metro'
    ]),
    DateQuestion('end_rating', '⭐', 'Rate our pretend date?',
        ['⭐ 7/10', '🌟 9/10', '💯 10/10', '🚀 Off the charts']),
    DateQuestion('end_souvenir', '🎟️', 'Keep a souvenir?', [
      '🎟️ Ticket stub',
      '🧾 Receipt',
      '📸 Photo print',
      '🌸 Pressed flower'
    ]),
    DateQuestion('end_late', '🌃', 'Date running late?',
        ['⏳ Extend it', '🏠 Wrap up', '☕ One more coffee', '🌅 Watch sunrise']),
    DateQuestion('end_fave_moment', '💭', 'Best part of a date?',
        ['🍽️ The food', '😂 The laughs', '💬 The talks', '🌙 The goodbye']),
    DateQuestion('end_highlight', '🌟', "We'll remember the date for…",
        ['😂 Inside jokes', '🍰 The dessert', '🌅 The view', '💬 Long talks']),
    DateQuestion('end_journal', '📓', 'After the date, we…', [
      '📓 Journal about it',
      '📞 Tell a best friend',
      '🎵 Make a playlist',
      '😴 Sleep smiling'
    ]),
    DateQuestion('end_song', '🎶', 'Song for the ride home?', [
      '🎶 Soft romantic',
      '🪩 Upbeat dance',
      '🎤 Loud singalong',
      '🔇 Quiet calm'
    ]),
    DateQuestion('second_date', '2️⃣', 'Second-date idea?',
        ['🎳 Bowling', '🍳 Cook together', '🥾 Hike', '🎨 Art class']),
    DateQuestion('second_date_when', '📆', "When's the second date?", [
      '⚡ Tomorrow',
      '📅 Next weekend',
      '🗓️ In two weeks',
      '🎲 Surprise me'
    ]),
    DateQuestion('second_date_upgrade', '⬆️', 'Second date should be…', [
      '🔁 Same, but better',
      '🆕 Totally new',
      '🧭 More adventurous',
      '🛋️ Cozier'
    ]),
    DateQuestion('second_date_food', '🍜', 'Second-date food?', [
      '🍜 New cuisine',
      '🧑‍🍳 Home-cooked',
      '🌮 Street crawl',
      '🍰 Dessert-only date'
    ]),
    DateQuestion('second_date_activity', '🎯', 'Second-date activity?',
        ['🎢 Theme park', '🧗 Climbing', '🎬 Double feature', '🛶 Boating']),
    DateQuestion('second_date_place', '📍', 'Second-date spot?',
        ['🏞️ A lake', '🏙️ A rooftop', '🏛️ A museum', '🎪 A fair']),
    DateQuestion('third_date', '3️⃣', 'Third-date idea?',
        ['🏕️ Day trip', '🎤 Karaoke', '🍳 Brunch', '🎟️ Live show']),
    DateQuestion('date_series', '🗓️', 'Monthly date tradition?', [
      '🍜 Try a new food',
      '🎬 Cinema night',
      '🌳 Nature walk',
      '🎲 Game night'
    ]),
    DateQuestion('date_anniversary', '💞', 'Our date-versary plan?', [
      '🔁 Recreate first date',
      '✈️ Weekend trip',
      '🍽️ Fancy dinner',
      '💌 Letters exchange'
    ]),
    DateQuestion('date_tradition', '🔁', 'Couple tradition to start?', [
      '🥞 Sunday pancakes',
      '🌅 Monthly sunrise',
      '📸 Yearly photo',
      '🎁 Tiny gifts'
    ]),
    DateQuestion('date_rating_system', '📊', 'How do we rate dates?',
        ['⭐ Stars', '🍕 Pizza slices', '😂 Laughs count', '💌 Short review']),
    DateQuestion('date_jar', '🫙', 'Date idea jar first pick?',
        ['🌌 Stargazing', '🍳 New recipe', '🎨 Paint night', '🚲 Bike ride']),
    DateQuestion('date_virtual', '💻', 'Long-distance date?', [
      '🎬 Watch-party',
      '🎮 Online game',
      '🍳 Cook on video',
      '💬 Late-night call'
    ]),
    DateQuestion('date_double', '👥', 'Double date?',
        ['💯 Fun!', '🤔 Maybe later', '🙅 Just us', '🎲 With the right pair']),
    DateQuestion('date_group', '🎉', 'Group outing or just us?', [
      '💑 Just us',
      '👥 Small group',
      '🎉 Big party',
      '🔀 Start group, end two'
    ]),
    DateQuestion('date_family_meet', '🏡', 'Meeting friends one day?',
        ['🍕 Pizza night', '🎲 Game night', '🍽️ Dinner', '🏏 Gully cricket']),
    DateQuestion('date_mini', '⏱️', '15-minute mini date?',
        ['☕ Coffee run', '🍦 Ice cream', '🚶 Quick walk', '🌅 Sunset glance']),
    DateQuestion('date_spontaneous_call', '📞', 'Spontaneous date text?', [
      '😍 "I\'m outside!"',
      '📍 "Meet in 30"',
      '🍕 "Pizza?"',
      '🌙 "Stargaze?"'
    ]),
    DateQuestion('date_breakfast_bed', '🛌', 'Breakfast in bed menu?',
        ['🥞 Pancakes', '🥐 Croissants', '🫓 Parathas', '🥣 Cereal & fruit']),
    DateQuestion('date_staycation', '🏨', 'Staycation plan?',
        ['🏨 Hotel pool', '🍽️ Room service', '🧖 Spa', '🎬 Movie night']),
    DateQuestion('date_sunday', '☀️', 'Ideal Sunday together?',
        ['😴 Sleep in', '🥞 Brunch', '🧺 Picnic', '🎬 Movie marathon']),
    DateQuestion('date_rainy_sunday', '🌧️', 'Rainy Sunday?',
        ['🧅 Pakode & chai', '📚 Read', '🎮 Games', '😴 Nap']),
    DateQuestion('date_bucket_first', '✅', 'First bucket-list date?', [
      '🎈 Hot air balloon',
      '🐋 Whale watching',
      '🏔️ Snow trip',
      '🌌 Desert stars'
    ]),
    DateQuestion('quick_tea_coffee', '⚡', 'Quick pick: tea or coffee?',
        ['🫖 Tea', '☕ Coffee', '🥛 Hot milk', '🧃 Juice']),
    DateQuestion('quick_sweet_salty', '⚡', 'Quick pick: chips or chocolate?',
        ['🥔 Chips', '🍫 Chocolate', '🍿 Popcorn', '🥜 Nuts']),
    DateQuestion('quick_mountain_sea', '⚡', 'Quick pick: hills or sea?',
        ['⛰️ Hills', '🌊 Sea', '🏜️ Desert', '🌲 Forest']),
    DateQuestion('quick_books_movies', '⚡', 'Quick pick: book or its movie?',
        ['📖 Book', '🎬 Movie', '📺 Series version', '🎧 Audiobook']),
    DateQuestion('quick_sun_moon', '⚡', 'Quick pick: sun or moon?',
        ['☀️ Sun', '🌙 Moon', '⭐ Stars', '☁️ Clouds']),
    DateQuestion('quick_call_text', '⚡', 'Quick pick: call or text?',
        ['📞 Call', '💬 Text', '🎙️ Voice note', '🎥 Video call']),
    DateQuestion('quick_summer_winter', '⚡', 'Quick pick: summer or winter?',
        ['☀️ Summer', '❄️ Winter', '🌧️ Monsoon', '🌸 Spring']),
    DateQuestion('quick_pizza_burger', '⚡', 'Quick pick: pizza or burger?',
        ['🍕 Pizza', '🍔 Burger', '🌯 Wrap', '🥪 Sandwich']),
    DateQuestion('quick_dance_sing', '⚡', 'Quick pick: dance or sing?',
        ['💃 Dance', '🎤 Sing', '🥁 Play drums', '👏 Cheer']),
    DateQuestion(
        'quick_city_village',
        '⚡',
        'Quick pick: city lights or village calm?',
        ['🏙️ City lights', '🌾 Village calm', '🏘️ Small town', '🏝️ Island']),
    DateQuestion('quick_spicy_sweet', '⚡', 'Quick pick: golgappa or ice cream?',
        ['🍢 Golgappa', '🍦 Ice cream', '🥟 Momos', '🍩 Donut']),
    DateQuestion('quick_left_right', '⚡', 'Quick pick: plan or flow?',
        ['📋 Plan', '🌊 Flow', '🎲 Dice', '🪙 Coin']),
    DateQuestion('quick_bike_car', '⚡', 'Quick pick: bike or car?',
        ['🏍️ Bike', '🚗 Car', '🚲 Cycle', '🚶 Walk']),
    DateQuestion('quick_netflix_out', '⚡', 'Quick pick: stay in or go out?',
        ['🏠 Stay in', '🚪 Go out', '🌳 Backyard', '🏙️ Rooftop']),
    DateQuestion('quick_cake_pie', '⚡', 'Quick pick: cake or pie?',
        ['🎂 Cake', '🥧 Pie', '🧁 Cupcake', '🍪 Cookie']),
    DateQuestion('quick_cats_dogs2', '⚡', 'Quick pick: puppies or kittens?',
        ['🐶 Puppies', '🐱 Kittens', '🐰 Bunnies', '🐥 Ducklings']),
    DateQuestion(
        'quick_sunrise_sleep', '⚡', 'Quick pick: sunrise or sleep in?', [
      '🌅 Sunrise',
      '😴 Sleep in',
      '☕ Sunrise then nap',
      '🌇 Sunset instead'
    ]),
    DateQuestion('quick_old_new_songs', '⚡', 'Quick pick: old songs or new?',
        ['📻 Old', '🆕 New', '🔀 Remixes', '🎻 Instrumental']),
    DateQuestion('quick_beach_pool', '⚡', 'Quick pick: beach or pool?',
        ['🏖️ Beach', '🏊 Pool', '🏞️ Lake', '🛁 Bathtub']),
    DateQuestion('quick_hot_cold', '⚡', 'Quick pick: hot drink or cold drink?',
        ['☕ Hot', '🧊 Cold', '🌡️ Lukewarm', '💧 Water']),
    DateQuestion('quick_noodles_rice', '⚡', 'Quick pick: noodles or rice?',
        ['🍜 Noodles', '🍚 Rice', '🫓 Roti', '🥖 Bread']),
    DateQuestion('quick_comedy_drama', '⚡', 'Quick pick: comedy or drama?',
        ['😂 Comedy', '🎭 Drama', '😱 Thriller', '💕 Romance']),
    DateQuestion('quick_mall_market', '⚡', 'Quick pick: mall or street market?',
        ['🏬 Mall', '🛍️ Street market', '📱 Online', '🧺 Flea market']),
    DateQuestion('quick_window_aisle2', '⚡', 'Quick pick: train or plane?',
        ['🚆 Train', '✈️ Plane', '🚌 Bus', '🚢 Ship']),
    DateQuestion(
        'quick_early_late2',
        '⚡',
        'Quick pick: early bird or late owl?',
        ['🐦 Early bird', '🦉 Night owl', '🐨 Nap champion', '🐝 Always busy']),
    DateQuestion('quick_handwritten', '⚡', 'Quick pick: letter or text?',
        ['✉️ Handwritten letter', '📱 Text', '📧 Email', '🦜 Carrier pigeon']),
    DateQuestion('quick_gold_silver', '⚡', 'Quick pick: gold or silver?',
        ['🥇 Gold', '🥈 Silver', '🌹 Rose gold', '⚫ Matte black']),
    DateQuestion('quick_rain_snow', '⚡', 'Quick pick: rain or snow?',
        ['🌧️ Rain', '❄️ Snow', '🌫️ Fog', '☀️ Neither']),
    DateQuestion('quick_paint_photo', '⚡', 'Quick pick: painting or photo?',
        ['🎨 Painting', '📸 Photo', '✏️ Sketch', '🎥 Video']),
    DateQuestion('quick_vanilla_choc', '⚡', 'Quick pick: vanilla or chocolate?',
        ['🍦 Vanilla', '🍫 Chocolate', '🍓 Strawberry', '🧂 Salted caramel']),
    DateQuestion('quick_hug_highfive', '⚡', 'Quick pick: hug or high five?',
        ['🤗 Hug', '🙌 High five', '👊 Fist bump', '🤝 Handshake']),
    DateQuestion('quick_samosa_fries', '⚡', 'Quick pick: samosa or fries?',
        ['🥟 Samosa', '🍟 Fries', '🧆 Falafel', '🥔 Tikki']),
    DateQuestion('home_date', '🏠', 'Stay-at-home date?', [
      '🎬 Movie night',
      '🍳 Cook together',
      '🎲 Game night',
      '🧖 Spa night'
    ]),
    DateQuestion('home_living_room', '🛋️', 'Living room makeover for a date?',
        ['✨ Fairy lights', '🏕️ Indoor tent', '🕯️ Candles', '🎈 Balloons']),
    DateQuestion('home_movie_setup', '📽️', 'Home movie setup?', [
      '📽️ Projector on wall',
      '💻 Laptop in bed',
      '📺 Big TV',
      '📱 Phone propped up'
    ]),
    DateQuestion('home_dinner_theme', '🍽️', 'Home dinner theme?', [
      '🇮🇹 Italian night',
      '🇮🇳 Desi feast',
      '🇲🇽 Taco night',
      '🇯🇵 Sushi night'
    ]),
    DateQuestion('home_dessert_make', '🍫', 'Make dessert at home?',
        ['🍫 Brownies', '🍮 Custard', '🍪 Cookies', '🍓 Choco-dipped fruit']),
    DateQuestion('home_fort', '🏰', 'Pillow fort size?', [
      '🏠 Small & cozy',
      '🏰 Castle-sized',
      '🛏️ Whole bedroom',
      '🏕️ Balcony camp'
    ]),
    DateQuestion('home_cleanup', '🧽', 'After dinner cleanup?', [
      '🧽 Wash together',
      '🎶 Dance while cleaning',
      '🪙 Coin toss',
      "⏰ Tomorrow's problem"
    ]),
    DateQuestion('home_pajama', '🩳', 'Pajama style?', [
      '🐼 Animal onesie',
      '👕 Old tee',
      '🌙 Matching set',
      '🧦 Socks & hoodie'
    ]),
    DateQuestion('home_balcony', '🌙', 'Balcony evening?',
        ['🫖 Chai', '🎸 Guitar', '🌌 Stars', '🪴 Plant chat']),
    DateQuestion('home_breakfast', '🍳', 'Weekend breakfast at home?',
        ['🥞 Pancakes', '🫓 Aloo parathas', '🍳 Eggs & toast', '🥣 Poha']),
    DateQuestion('home_karaoke', '🎤', 'Home karaoke song?', [
      '🎶 Bollywood duet',
      '🎸 Rock ballad',
      '🪩 Disco hit',
      '🧸 Cartoon theme'
    ]),
    DateQuestion('home_bake_bread', '🍞', 'Bake from scratch?',
        ['🍞 Bread', '🍕 Pizza dough', '🥨 Pretzels', '🍩 Donuts']),
    DateQuestion('home_tv_genre', '📺', 'Comfort TV?', [
      '😂 Sitcom reruns',
      '🍳 Cooking shows',
      '🐾 Animal docs',
      '🏠 Home makeovers'
    ]),
    DateQuestion('home_rearrange', '🪑', 'Rearrange the room?', [
      '🛋️ Move the couch',
      '🖼️ Hang art',
      '🪴 Add plants',
      '💡 New lights'
    ]),
    DateQuestion('home_puzzle_night', '🧩', 'Jigsaw theme?',
        ['🌌 Space', '🏙️ City skyline', '🐱 Cats', '🍬 Candy land']),
    DateQuestion('home_indoor_picnic', '🧺', 'Indoor picnic menu?', [
      '🥪 Finger sandwiches',
      '🍇 Fruit plate',
      '🧁 Cupcakes',
      '🥟 Samosas'
    ]),
    DateQuestion('home_spa_item', '🧖', 'Spa essential?',
        ['🥒 Cucumber eyes', '🧴 Face mask', '🦶 Foot soak', '🛁 Bath bomb']),
    DateQuestion('home_game_console', '🕹️', 'Console night snack?',
        ['🍕 Pizza', '🍿 Popcorn', '🍜 Noodles', '🍫 Chocolate']),
    DateQuestion('home_cook_challenge', '⏱️', 'Who cooks better?',
        ['🙋 Me', '👉 You', '🤝 Equal', '🔥 Neither, order in']),
    DateQuestion('home_movie_blanket', '🛏️', 'Blanket split during movie?', [
      '🌯 One blanket',
      '🛏️ Two blankets',
      '🔥 No blanket',
      '😼 Blanket thief'
    ]),
    DateQuestion('home_rainy_night', '🌧️', 'Rainy night in?',
        ['🕯️ Candle & music', '🍜 Hot noodles', '📖 Read aloud', '🎲 Cards']),
    DateQuestion('home_photo_album', '📒', 'Look through old photos?',
        ['👶 Baby pics', '🏫 School days', '✈️ Trips', '😂 Awkward phases']),
    DateQuestion('nature_spot', '🌿', 'Nature date?',
        ['🥾 Hike', '🏞️ Lake', '🌻 Flower fields', '🏖️ Beach']),
    DateQuestion('nature_sound', '🎧', 'Favorite nature sound?',
        ['🌊 Waves', '🌧️ Rain', '🐦 Birds', '🍃 Wind in trees']),
    DateQuestion('nature_hike_snack', '🥾', 'Hiking snack?',
        ['🥜 Trail mix', '🍫 Energy bar', '🍌 Banana', '🥪 Sandwich']),
    DateQuestion('nature_camp', '🏕️', 'Camping style?',
        ['⛺ Tent', '🚐 Campervan', '🛖 Glamping', '🌌 Under open sky']),
    DateQuestion('nature_campfire_food', '🔥', 'Campfire food?',
        ["🍡 S'mores", '🌽 Corn', '🥔 Baked potato', '🍢 Paneer skewers']),
    DateQuestion('nature_trail', '🗺️', 'Trail difficulty?',
        ['🚶 Easy', '🥾 Moderate', '🧗 Challenging', '🛺 Drive to the top']),
    DateQuestion('nature_waterfall', '💧', 'At a waterfall, we…',
        ['📸 Photos', '💦 Get splashed', '🧺 Picnic', '🤐 Just listen']),
    DateQuestion('nature_flowers', '🌼', 'Field of flowers?',
        ['🌻 Sunflowers', '🌷 Tulips', '💜 Lavender', '🌼 Marigolds']),
    DateQuestion('nature_tree', '🌳', 'Climb a tree?', [
      '🧗 Absolutely',
      '🌳 Sit under it',
      '📸 Photo with it',
      '🙅 Too scared'
    ]),
    DateQuestion('nature_beach_act', '🏖️', 'Beach activity?',
        ['🏰 Sandcastle', '🏐 Volleyball', '🐚 Shell hunt', '🌅 Sunset watch']),
    DateQuestion('nature_safari', '🐘', 'Safari pick?', [
      '🐅 Tiger reserve',
      '🦁 African savanna',
      '🐘 Elephant camp',
      '🦩 Bird lake'
    ]),
    DateQuestion('nature_garden_walk', '🦋', 'In a garden we spot…',
        ['🦋 Butterflies', '🐝 Bees', '🐿️ Squirrels', '🐦 Birds']),
    DateQuestion('nature_sunbathe', '🌞', 'Beach day energy?', [
      '😎 Sunbathe',
      '🏊 Swim',
      '🍹 Mocktails in shade',
      '📖 Read under umbrella'
    ]),
    DateQuestion('nature_stars', '✨', 'Constellation to find?',
        ['🏹 Orion', '🐻 Big Dipper', '🦂 Scorpius', '💫 Make our own']),
    DateQuestion('nature_leaves', '🍁', 'Autumn leaves?',
        ['🍂 Jump in piles', '📸 Photos', '🎨 Leaf art', '🚶 Crunchy walk']),
    DateQuestion('nature_moon', '🌕', 'Full-moon plan?', [
      '🌕 Moon walk',
      '🏖️ Moonlit beach',
      '📸 Moon photos',
      '🐺 Howl at it'
    ]),
    DateQuestion('nature_eco', '♻️', 'Eco date?', [
      '🧹 Beach cleanup',
      '🌳 Tree planting',
      '🚲 Car-free day',
      '🛍️ Zero-waste market'
    ]),
    DateQuestion('nature_cave', '🕳️', 'Cave exploring?', [
      '🔦 Flashlights on',
      '🦇 Look for bats',
      '🗣️ Echo shouting',
      '🙅 Nope'
    ]),
    DateQuestion('nature_river', '🏞️', 'By a river, we…',
        ['🦶 Dip our feet', '🛶 Raft', '🪨 Skip stones', '🧺 Picnic']),
    DateQuestion('nature_glacier', '🧊', 'Ice landscape?', [
      '🧊 Glacier hike',
      '❄️ Snowfield',
      '🏔️ Ice cave',
      '🐧 Penguin colony'
    ]),
    DateQuestion('nature_volcano', '🌋', 'Volcano trip?', [
      '🌋 Hike to crater',
      '♨️ Hot springs nearby',
      '📸 From afar',
      '🙅 Too risky'
    ]),
    DateQuestion('nature_sunrise_hike', '🌄', 'Sunrise hike breakfast?',
        ['🫖 Thermos chai', '🥪 Sandwiches', '🍌 Fruits', '🍫 Chocolate']),
    DateQuestion('nature_backyard', '🌱', 'Backyard date?',
        ['🏕️ Tent camping', '🔥 Fire pit', '🌻 Gardening', '🌌 Stargazing']),
    DateQuestion('art_form', '🎨', "Art we'd make together?",
        ['🎨 Painting', '📸 Photography', '🏺 Pottery', '🎼 Music']),
    DateQuestion('art_museum_piece', '🖼️', "Art style we'd hang at home?",
        ['🌅 Landscapes', '🟥 Abstract', '🐱 Cute animals', '📸 Our photos']),
    DateQuestion('art_street', '🧱', 'Street art walk?', [
      '🎨 Murals',
      '✍️ Graffiti tags',
      '🗿 Sculptures',
      '🎭 Street performers'
    ]),
    DateQuestion('art_dance_show', '🩰', 'Dance performance?',
        ['🩰 Ballet', '💃 Kathak', '🕺 Hip-hop battle', '🪩 Salsa night']),
    DateQuestion('art_craft_fair', '🧵', 'Craft fair buy?', [
      '🏺 Handmade pottery',
      '🧶 Woolen stuff',
      '📿 Jewelry',
      '🕯️ Candles'
    ]),
    DateQuestion('art_poetry', '📜', 'Poetry night?', [
      '🎤 Perform a poem',
      '👂 Just listen',
      '✍️ Write together',
      '😂 Silly limericks'
    ]),
    DateQuestion('art_film_fest', '🎞️', 'Film festival pick?', [
      '🌍 World cinema',
      '🎨 Animation',
      '🎥 Short films',
      '📽️ Silent classic'
    ]),
    DateQuestion('art_photography', '📷', 'Photography style?',
        ['📱 Phone shots', '🎞️ Film camera', '📷 Polaroid', '🚁 Drone shots']),
    DateQuestion('art_music_class', '🎻', 'Music class?',
        ['🎸 Guitar', '🎹 Keyboard', '🥁 Tabla', '🎤 Vocals']),
    DateQuestion('art_sketch_spot', '✏️', 'Sketching spot?',
        ['☕ Café', '🌳 Park bench', '🏛️ Museum', '🚆 Train ride']),
    DateQuestion('art_calligraphy', '🖋️', 'Calligraphy practice?',
        ['🔤 Our names', '💌 A quote', '🎂 Birthday card', '🪧 Wall sign']),
    DateQuestion('art_open_mic', '🎙️', "Open mic night, we'd…",
        ['🎤 Sing', '📜 Read poetry', '😂 Do stand-up', '👏 Cheer loudest']),
    DateQuestion('art_mural', '🖌️', 'Paint a mural of…',
        ['🌅 A sunset', '🐳 Ocean life', '🌌 Galaxy', '🍕 Giant pizza']),
    DateQuestion('art_pottery_make', '🫖', 'Make in pottery?',
        ['🫖 Teapot', '🍜 Bowls', '🪴 Plant pot', '🫠 Abstract blob']),
    DateQuestion('art_theatre_role', '🎭', 'If we acted in a play…',
        ['🎭 Lead roles', '🌳 The tree', '🎬 Director', '💡 Lights crew']),
    DateQuestion('book_genre', '📚', "Book genre we'd read together?",
        ['🔍 Mystery', '💕 Romance', '🚀 Sci-fi', '🐉 Fantasy']),
    DateQuestion('book_format', '📖', 'Reading format?',
        ['📖 Paperback', '📱 E-reader', '🎧 Audiobook', '📰 Comics']),
    DateQuestion('book_spot', '🛋️', 'Favorite reading spot?',
        ['🛋️ Couch', '🛏️ Bed', '🌳 Under a tree', '☕ Café corner']),
    DateQuestion('book_character', '🧙', 'Book character to date-night with?',
        ['🧙 Wizard', '🕵️ Detective', '🏴‍☠️ Pirate', '🧚 Fairy']),
    DateQuestion('book_ending', '📕', 'Favorite kind of ending?',
        ['😊 Happy', '😢 Bittersweet', '🤯 Plot twist', '🔓 Open-ended']),
    DateQuestion('book_comic', '💥', 'Comic universe?',
        ['🦸 Marvel', '🦇 DC', '🍥 Manga', '🇮🇳 Amar Chitra Katha']),
    DateQuestion('book_childhood', '🧒', 'Childhood story book?', [
      '🐯 Panchatantra',
      '🧙 Harry Potter',
      '🔍 Famous Five',
      '🧸 Winnie the Pooh'
    ]),
    DateQuestion('book_poem_type', '✒️', 'Poem type?',
        ['❤️ Love poem', '😂 Funny rhyme', '🌿 Haiku', '🎶 Song lyrics']),
    DateQuestion('book_dog_ear', '🔖', 'Dog-ear pages or bookmark?',
        ['🔖 Bookmark', '📄 Dog-ear', '🧾 Random receipt', '🧠 Memory only']),
    DateQuestion('book_writing', '✍️', 'If we co-wrote a book…',
        ['💕 Romance', '🔍 Thriller', '🍳 Cookbook', '🗺️ Travel diary']),
    DateQuestion('tech_app_date', '📱', 'App-based date?', [
      '🎮 Online game',
      '🎬 Watch party',
      '🗺️ Map treasure hunt',
      '🎧 Shared playlist'
    ]),
    DateQuestion('tech_gadget', '🔌', 'Gadget for date night?', [
      '📽️ Mini projector',
      '📷 Instant camera',
      '🔊 Speaker',
      '🎮 Handheld console'
    ]),
    DateQuestion('tech_photo_filter', '🤳', 'Photo filter?',
        ['🚫 No filter', '🐶 Puppy ears', '📼 Vintage', '🌈 Sparkles']),
    DateQuestion('tech_screen_time', '📵', 'Screen time on dates?',
        ['📵 Zero', '📸 Photos only', '📱 Some', '🎮 Lots, gamers']),
    DateQuestion('tech_ai_planner', '🤖', 'Let an app plan our date?',
        ['🤖 Yes, fun', '🧠 Only ideas', '🙅 We plan', '🎲 Roll the dice']),
    DateQuestion('tech_video_call', '🎥', 'Video call background?',
        ['🏖️ Beach', '🚀 Space', '🐱 Cats', '🛏️ Real messy room']),
    DateQuestion('tech_voice_note', '🎙️', 'Voice notes?',
        ['🎙️ Love them', '🎧 1.5x speed', '💬 Text please', '🎵 Only songs']),
    DateQuestion('tech_game_genre', '🕹️', 'Game genre?',
        ['🏎️ Racing', '🧩 Puzzle', '🧙 RPG', '⚔️ Battle royale']),
    DateQuestion('tech_streak', '🔥', 'Keeping a chat streak?',
        ['🔥 Must keep', '😅 Sometimes', "🤷 Don't care", '📸 Daily photo']),
    DateQuestion('tech_smart_home', '🏠', 'Smart home trick?', [
      '💡 Mood lights',
      '🎵 Auto music',
      '🤖 Robot vacuum',
      '🗣️ Voice assistant'
    ]),
    DateQuestion('tech_meme_share', '😂', 'Sharing memes per day?',
        ['1️⃣ One or two', '🔟 Ten', '💯 Hundreds', '🙅 None']),
    DateQuestion('tech_emoji_combo', '💬', 'Best emoji combo?',
        ['🥺👉👈 Shy', '😂💀 Dead laughing', '🍕❤️ Food love', '✨🌙 Dreamy']),
    DateQuestion('wellness_date', '🧘', 'Wellness date?',
        ['🧘 Yoga', '🧖 Spa', '🚶 Nature walk', '🛌 Nap date']),
    DateQuestion('wellness_meditate', '🕉️', 'Relax together?',
        ['🧘 Meditate', '🎧 Calm music', '🛁 Warm bath', '🌳 Forest walk']),
    DateQuestion('wellness_healthy_habit', '🥗', 'Healthy habit together?', [
      '💧 More water',
      '🏃 Morning walks',
      '🍎 Fruit snacks',
      '😴 Early bedtime'
    ]),
    DateQuestion('wellness_massage', '💆', 'Massage type?',
        ['💆 Head', '🦶 Foot', '🙌 Shoulder', '🧴 Hand']),
    DateQuestion('wellness_digital_detox', '📵', 'Digital detox day?',
        ['🌳 Outdoors', '📚 Books', '🎨 Crafts', '😴 Sleep']),
    DateQuestion('wellness_sauna', '♨️', 'Steam or cold plunge?',
        ['♨️ Steam room', '🧊 Cold plunge', '🔀 Both', '🙅 Neither']),
    DateQuestion('wellness_journal', '📓', 'Gratitude journal together?',
        ['📓 Daily', '📅 Weekly', '💬 Just say it', '🙅 Not for us']),
    DateQuestion('wellness_bedtime', '😴', 'Bedtime routine?',
        ['📖 Read', '🎧 Podcast', '🌙 Stargaze', '📱 Scroll (guilty)']),
    DateQuestion('wellness_comfort', '🫂', 'Comfort on a bad day?',
        ['🫂 Hugs', '🍫 Snacks', '😂 Funny videos', '🚶 Quiet walk']),
    DateQuestion('wellness_stretch', '🤸', 'Morning stretch?',
        ['🤸 Yoga flow', '🙆 Quick stretch', '💃 Dance it out', '😴 Snooze']),
    DateQuestion('us_superlative', '🏆', "Who's more likely to get lost?",
        ['🙋 Me', '👉 You', '😂 Both', '🧭 Neither']),
    DateQuestion('us_dance_first', '💃', 'Who dances first at a party?',
        ['🙋 Me', '👉 You', '🕺 Together', '🙈 Nobody']),
    DateQuestion('us_cry_movie', '😭', 'Who cries first at a sad movie?',
        ['🙋 Me', '👉 You', '😭 Both', '😎 Neither']),
    DateQuestion('us_cook_better', '🍳', "Who's the better cook?",
        ['🙋 Me', '👉 You', '🤝 Tie', '📱 Delivery app']),
    DateQuestion('us_plan_trips', '🗺️', "Who'd plan our trips?",
        ['🙋 Me', '👉 You', '🤝 Together', '🎲 Let fate decide']),
    DateQuestion('us_wake_first', '⏰', 'Who wakes up first?',
        ['🙋 Me', '👉 You', '⏰ Alarm wins', '😴 Neither']),
    DateQuestion('us_funnier', '😂', "Who's funnier?",
        ['🙋 Me', '👉 You', '🤝 Equally', '🤡 Both unintentionally']),
    DateQuestion(
        'us_say_sorry',
        '🕊️',
        'After a silly fight, who says sorry first?',
        ['🙋 Me', '👉 You', '🤝 Both together', '🍫 Chocolate bringer']),
    DateQuestion('us_snack_thief', '🍪', "Who's the snack thief?",
        ['🙋 Me', '👉 You', '😋 Both', '🐶 The pet']),
    DateQuestion('us_late_more', '⏳', 'Who runs late more?',
        ['🙋 Me', '👉 You', '⏳ Both', '⏰ Neither']),
    DateQuestion('us_brave_bug', '🕷️', 'Who handles the spider?',
        ['🙋 Me', '👉 You', '🏃 Both run', '🫙 Gentle jar rescue']),
    DateQuestion('us_couple_type', '💑', 'What kind of couple are we?',
        ['😂 Goofy', '🌹 Romantic', '🧭 Adventurous', '☕ Cozy']),
    DateQuestion('us_secret_handshake', '🤝', 'Secret handshake?', [
      '👊 Fist bump combo',
      '✋ High-five chain',
      '🤙 Pinky swear',
      '💃 Dance move'
    ]),
    DateQuestion('us_motto', '📣', 'Couple motto?', [
      '🍕 Pizza first',
      '🎲 Say yes to fun',
      '😂 Laugh daily',
      '🧭 Explore always'
    ]),
    DateQuestion('us_theme_song', '🎵', 'Our theme song mood?', [
      '🎶 Upbeat pop',
      '🎻 Soft ballad',
      '🎸 Rock anthem',
      '🎶 Bollywood romance'
    ]),
    DateQuestion('us_color', '🎨', 'Our couple color?',
        ['💜 Purple', '🧡 Orange', '💚 Green', '💛 Yellow']),
    DateQuestion('us_emoji', '😊', 'Our couple emoji?',
        ['🦦 Otters', '🐧 Penguins', '🍕 Pizza', '🌙 Moon']),
    DateQuestion('us_strength', '💪', 'Our strength as a team?',
        ['😂 Humor', '🗣️ Talking', '🧭 Adventure', '🍳 Food']),
    DateQuestion('us_role_trip', '🧳', 'Trip roles?', [
      '🗺️ Navigator',
      '📸 Photographer',
      '🍜 Food scout',
      '💰 Budget keeper'
    ]),
    DateQuestion('us_texting_first', '📱', 'Who texts first in the morning?',
        ['🙋 Me', '👉 You', '🌅 Whoever wakes', '🔁 We alternate']),
    DateQuestion('us_movie_choice', '🎬', 'Who picks the movie faster?',
        ['🙋 Me', '👉 You', '⏳ Endless scrolling', '🎲 Random pick']),
    DateQuestion('us_dj', '🎧', 'Who controls the playlist?',
        ['🙋 Me', '👉 You', '🔀 Shuffle', '🗳️ Song-by-song vote']),
    DateQuestion('us_pet_parent', '🐶', "Who'd be the strict pet parent?",
        ['🙋 Me', '👉 You', '🍪 Neither, spoiled pet', '🤝 Both']),
    DateQuestion('us_gift_giver', '🎁', 'Who gives better gifts?',
        ['🙋 Me', '👉 You', '🤝 Equal', "🎁 We'll find out"]),
    DateQuestion('us_karaoke_star', '🎤', 'Karaoke star?',
        ['🙋 Me', '👉 You', '🎤 Duet stars', '🙈 Both shy']),
    DateQuestion('kid_childhood_date', '🧒', 'Childhood-style date?', [
      '🎠 Playground swings',
      '🍭 Candy shop',
      '🎈 Balloon fight',
      '🧃 Juice & cartoons'
    ]),
    DateQuestion('kid_cartoon', '📺', 'Cartoon marathon?',
        ['🐭 Tom & Jerry', '🐱 Doraemon', '🧽 SpongeBob', '🦸 Shaktimaan']),
    DateQuestion('kid_snack', '🍬', 'Childhood snack revival?', [
      '🍬 Orange candy',
      '🍫 Choco bar',
      '🥛 Biscuits & milk',
      '🍡 Imli candy'
    ]),
    DateQuestion('kid_game', '🪀', 'Childhood game rematch?',
        ['🪀 Yo-yo', '🪁 Kites', '🧱 Building blocks', '🔵 Marbles']),
    DateQuestion('kid_playground', '🛝', 'Playground pick?',
        ['🛝 Slide', '🎠 Swings', '🔄 Merry-go-round', '🧗 Jungle gym']),
    DateQuestion('kid_drawing', '🖍️', 'Crayon art of…', [
      '🏠 Our dream house',
      '🌈 Rainbow world',
      '🐉 A dragon',
      '🧑‍🤝‍🧑 Stick-figure us'
    ]),
    DateQuestion('kid_bubbles', '🫧', 'Bubble fun?', [
      '🫧 Giant bubbles',
      '💨 Bubble wrap pop',
      '🛁 Bubble bath',
      '🧋 Bubble tea'
    ]),
    DateQuestion('kid_sandcastle', '🏰', 'Sandcastle design?',
        ['🏰 Classic castle', '🐢 Sand turtle', '🧜 Mermaid', '🌋 Volcano']),
    DateQuestion('kid_toy_store', '🧸', 'At a toy store we…', [
      '🧸 Hug teddies',
      '🚂 Play with trains',
      '🎲 Test games',
      '🪀 Buy one each'
    ]),
    DateQuestion('kid_school_memory', '🏫', 'School trip memory?', [
      '🚌 Bus songs',
      '🍱 Tiffin sharing',
      '🏞️ Picnic spot',
      '🎢 Fun park'
    ]),
    DateQuestion('kid_comic_hero', '🦸', 'Childhood hero?', [
      '🦸 Shaktimaan',
      '🕷️ Spider-Man',
      '🧙 Harry Potter',
      '🐒 Chhota Bheem'
    ]),
    DateQuestion('kid_ice_candy', '🍧', 'Summer childhood treat?', [
      '🍧 Ice gola',
      '🍦 Softy cone',
      '🥭 Mango pulp',
      '🍉 Watermelon slice'
    ]),
    DateQuestion('kid_hide_seek', '🙈', 'Hide-and-seek hiding spot?', [
      '🛏️ Under the bed',
      '🚪 Behind curtains',
      '🌳 Up a tree',
      '🧺 In the laundry pile'
    ]),
    DateQuestion('kid_sleepover', '🛌', 'Sleepover activity?',
        ['🔦 Ghost stories', '🍕 Midnight pizza', '🎬 Movies', '💅 Makeovers']),
    DateQuestion('night_out', '🌃', 'Night out plan (no clubbing needed)?', [
      '🎤 Karaoke',
      '🎳 Late bowling',
      '🍜 Night food walk',
      '🌌 Night drive'
    ]),
    DateQuestion('night_market', '🏮', 'Night market find?', [
      '🍢 Grilled skewers',
      '🧋 Bubble tea',
      '🛍️ Cute trinkets',
      '🎮 Retro games'
    ]),
    DateQuestion('night_cafe', '☕', '24-hour café order?',
        ['☕ Coffee', '🥞 Pancakes at 2 AM', '🍟 Fries', '🍰 Cheesecake']),
    DateQuestion('night_drive_music', '🚗', 'Night drive vibe?', [
      '🎶 Slow songs',
      '🎤 Loud singalong',
      '💬 Deep talks',
      '🤫 Quiet city lights'
    ]),
    DateQuestion('night_city_view', '🌃', 'City at night?', [
      '🌃 Skyline view',
      '🌉 Lit-up bridge',
      '🎡 Glowing ferris wheel',
      '🏮 Lantern street'
    ]),
    DateQuestion('night_rooftop_cafe', '🌙', 'Rooftop café evening?',
        ['🍹 Mocktails', '🍕 Pizza', '🫖 Chai & snacks', '🎶 Live music']),
    DateQuestion('night_moonlight_walk', '🌕', 'Moonlight walk where?',
        ['🏖️ Beach', '🌳 Park', '🏙️ Empty streets', '🌉 Bridge']),
    DateQuestion('night_late_snack', '🌯', '2 AM snack stop?',
        ['🌯 Shawarma', '🍜 Maggi stall', '🥪 Bun maska', '🍳 Egg roll']),
    DateQuestion('night_star_app', '🔭', 'Late-night sky event?', [
      '🌠 Meteor shower',
      '🌑 Lunar eclipse',
      '🪐 Planet spotting',
      '🛰️ Satellite pass'
    ]),
    DateQuestion('night_gaming', '🎮', 'All-night gaming?', [
      '🎮 Co-op campaign',
      '🏎️ Racing tournament',
      '🧩 Puzzle game',
      '😴 Fall asleep at 1'
    ]),
    DateQuestion('night_bonfire', '🔥', 'Bonfire night?',
        ['🎸 Songs', '👻 Stories', '🍡 Marshmallows', '🌌 Stars']),
    DateQuestion('city_explore', '🏙️', 'Exploring a new neighborhood?', [
      '🍜 Food first',
      '🏛️ History first',
      '🛍️ Shops first',
      '🎨 Art first'
    ]),
    DateQuestion('city_landmark', '🗿', 'Touristy landmark?', [
      '📸 Classic photo',
      '🏃 Skip the crowd',
      '🗺️ Hidden angle',
      '🧭 Guided tour'
    ]),
    DateQuestion('city_rooftop_hunt', '🏢', 'Rooftop hunting?', [
      '🌅 Sunset view',
      '🌃 Night lights',
      '☕ Rooftop café',
      '🌱 Rooftop garden'
    ]),
    DateQuestion('city_old_town', '🏮', 'Old town wander?', [
      '🏮 Lantern lanes',
      '🛕 Old architecture',
      '🍬 Old sweet shops',
      '📮 Vintage stores'
    ]),
    DateQuestion('city_metro_day', '🚇', 'Metro day pass adventure?',
        ['🎲 Random stop', '🔚 Last stop', '🍜 Food stops', '🏛️ Museum line']),
    DateQuestion('city_bookshop_crawl', '📚', 'Bookshop crawl?', [
      '📚 Three shops',
      '📖 One huge store',
      '💿 Book & record mix',
      '☕ Book café only'
    ]),
    DateQuestion('city_cafe_hop', '☕', 'Café hopping rule?', [
      '☕ One drink per café',
      '🍰 One dessert each',
      '📸 Photo at every stop',
      '🏆 Rate them all'
    ]),
    DateQuestion('city_park_bench', '🪑', 'On a park bench we…',
        ['🦆 Feed ducks', '👀 People watch', '💬 Talk for hours', '📖 Read']),
    DateQuestion('city_architecture', '🏛️', 'Building style we love?', [
      '🏛️ Colonial',
      '🏙️ Glass towers',
      '🛕 Ancient temples',
      '🏠 Colorful homes'
    ]),
    DateQuestion('city_festival_street', '🎪', 'Street festival?', [
      '🎶 Music stage',
      '🍢 Food stalls',
      '🎨 Art booths',
      '🎠 Kiddie rides'
    ]),
    DateQuestion('city_hidden_gem', '💎', 'Hidden gem type?', [
      '🍜 Tiny eatery',
      '🌿 Secret park',
      '🎶 Tiny music venue',
      '🖼️ Small gallery'
    ]),
    DateQuestion('shop_date', '🛍️', 'Shopping date first stop?', [
      '📚 Bookstore',
      '👟 Sneaker shop',
      '🏠 Home decor',
      '🍫 Chocolate store'
    ]),
    DateQuestion('shop_style', '🛒', 'Shopping style?', [
      '⚡ In and out',
      '🚶 Browse everything',
      '💸 Buy on impulse',
      '📋 Strict list'
    ]),
    DateQuestion('shop_thrift_find', '👚', 'Thrift store treasure?', [
      '🧥 Vintage jacket',
      '📻 Old radio',
      '📚 Rare book',
      '🕶️ Funky shades'
    ]),
    DateQuestion('shop_gift_shop', '🎁', 'Souvenir shop pick?',
        ['🧲 Magnet', '🧸 Plushie', '☕ Mug', '🖼️ Postcard']),
    DateQuestion('shop_grocery', '🛒', 'Grocery run game?', [
      '🛒 Trolley race',
      '🍫 Hidden treat',
      '🧺 Recipe hunt',
      '💸 Budget challenge'
    ]),
    DateQuestion('shop_window', '🪟', 'Window shopping for…', [
      '🏠 Dream furniture',
      '💍 Fancy jewelry',
      '🚗 Dream cars',
      '🎸 Instruments'
    ]),
    DateQuestion('shop_bazaar', '🪔', 'Haggling at a bazaar?', [
      '💪 Expert haggler',
      '😅 Too shy',
      '🎭 Act uninterested',
      '💸 Pay full price'
    ]),
    DateQuestion('shop_bookmark', '🔖', 'Buy each other a…',
        ['🔖 Bookmark', '🧦 Funny socks', '🖊️ Cute pen', '🍬 Candy jar']),
    DateQuestion('shop_online', '📦', 'Online shopping cart?', [
      '🛒 Full, never checkout',
      '📦 Daily parcels',
      '🙅 Rarely',
      '💬 Swap links'
    ]),
    DateQuestion('shop_electronics', '🎧', 'Gadget store?',
        ['🎧 Headphones', '📷 Cameras', '🎮 Games', '⌚ Watches']),
    DateQuestion('romance_level', '🌹', 'How romantic should our date be?',
        ['🌹 Very', '💕 Sweet', '😂 Mostly funny', '🎲 Surprise level']),
    DateQuestion('romance_gesture', '💌', 'Cute gesture?', [
      '💌 Hidden notes',
      '🌹 Single rose',
      '🎶 Song dedication',
      '☕ Surprise coffee'
    ]),
    DateQuestion('romance_classic', '🕯️', 'Classic romantic setting?', [
      '🕯️ Candlelit dinner',
      '🌹 Rose garden',
      '🌅 Sunset beach',
      '🎻 Violinist (pretend)'
    ]),
    DateQuestion('romance_movie_moment', '🎬', 'Rom-com moment to recreate?', [
      '🌧️ Rain dance',
      '🎤 Grand serenade',
      '🚉 Station goodbye',
      '🎡 Ferris wheel top'
    ]),
    DateQuestion('romance_love_language', '💞', 'Love language?',
        ['💬 Words', '🤗 Hugs', '🎁 Gifts', '🍳 Acts of care']),
    DateQuestion('romance_slow_dance', '💃', 'Slow dance where?',
        ['🍳 Kitchen', '🌧️ In the rain', '🌙 Balcony', '🏖️ Beach']),
    DateQuestion('romance_stars', '🌠', 'Shooting star wish?', [
      '✈️ Travel together',
      '🍕 Endless pizza',
      '😂 Lots of laughs',
      '🤫 Secret wish'
    ]),
    DateQuestion('romance_note_spot', '📝', 'Leave a sweet note in…',
        ['👜 Bag', '📚 A book', '🪞 Mirror', '🍱 Lunch box']),
    DateQuestion('romance_poem', '📜', 'Write a poem using…', [
      '🌹 Roses are red…',
      '🍕 Food rhymes',
      '🌙 Moon metaphors',
      '😂 Dad jokes'
    ]),
    DateQuestion('romance_flower_meaning', '🌸', 'Flower that says "us"?', [
      '🌻 Sunflower — happy',
      '🌹 Rose — classic',
      '🌼 Daisy — sweet',
      '🪷 Lotus — calm'
    ]),
    DateQuestion('romance_cheesy_line', '🧀', 'Cheesy pickup line theme?',
        ['🍕 Pizza puns', '🌌 Space puns', '☕ Coffee puns', '🐶 Pet puns']),
    DateQuestion('romance_promise', '🤙', 'Pinky promise to…', [
      '🍕 Share pizza',
      '📞 Always call back',
      '🎉 Celebrate small wins',
      '😂 Laugh daily'
    ]),
    DateQuestion('romance_sky_lantern', '🏮', 'Write on a sky lantern?', [
      '💭 A dream',
      '🙏 A thank-you',
      '💕 Our initials',
      '🌍 A place to visit'
    ]),
    DateQuestion('misc_date_name', '🏷️', 'Name our first date?', [
      '🌙 Operation Moonlight',
      '🍕 The Pizza Summit',
      '☕ Project Coffee',
      '🎲 Mission Random'
    ]),
    DateQuestion('misc_date_soundtrack', '🎼', 'Opening scene of our date?', [
      '🚶 Slow-mo walk-in',
      '😂 Tripping on entry',
      '👋 Awkward wave',
      '🌧️ Rain begins'
    ]),
    DateQuestion('misc_mascot_food', '🥔', 'If we were a snack combo…', [
      '🥔 Chips & dip',
      '🍪 Milk & cookies',
      '🫖 Chai & biscuit',
      '🍟 Fries & ketchup'
    ]),
    DateQuestion('misc_coin_toss', '🪙', 'We let a coin decide…', [
      '🍽️ Dinner spot',
      '🎬 The movie',
      '🗺️ Which way to walk',
      '🍨 Dessert'
    ]),
    DateQuestion('misc_dice_date', '🎲', 'Dice date: rolling a 6 means…',
        ['🎤 Karaoke', '🍦 Ice cream', '💃 Dance', '🎁 Buy a tiny gift']),
    DateQuestion('misc_fortune_cookie', '🥠', 'Fortune cookie says…', [
      '🗺️ Adventure awaits',
      '🍕 Eat the pizza',
      '💕 Say yes',
      "😂 You're hilarious"
    ]),
    DateQuestion('misc_magic_8ball', '🎱', 'Magic 8-ball asks: second date?', [
      '✅ Signs point to yes',
      '🔮 Ask again later',
      '💯 Definitely',
      '🤭 Very likely'
    ]),
    DateQuestion('misc_postcard', '📮', 'Postcard from our date says…', [
      '🌅 Wish you were here',
      '🍜 Ate too much',
      '😂 Laughed nonstop',
      '🌙 Stayed out late'
    ]),
    DateQuestion('misc_emoji_story', '📖', 'Our date in emojis?',
        ['☕🚶🌅', '🍕🎬🍦', '🎳🍔🎤', '🥾🏞️🧺']),
    DateQuestion('misc_alarm_song', '⏰', 'Song to wake up to?', [
      '🐦 Birdsong',
      '🎶 Favorite song',
      '📻 Radio news',
      '🔔 Classic beep'
    ]),
    DateQuestion('misc_wall_poster', '🖼️', 'Poster for our room?',
        ['🎬 Movie poster', '🗺️ World map', '🌌 Galaxy', '🐱 Funny cat']),
    DateQuestion('misc_hobby_new', '🆕', 'New hobby to start together?',
        ['🧗 Bouldering', '🎨 Watercolor', '🌱 Gardening', '🎹 Piano']),
    DateQuestion('misc_weekend_chore', '🧺', 'Weekend chore made fun?', [
      '🧺 Laundry & podcast',
      '🍳 Meal prep & music',
      '🧹 Clean & dance',
      '🛒 Grocery & snacks'
    ]),
    DateQuestion('misc_color_room', '🎨', 'Paint a room in…',
        ['💙 Calm blue', '💚 Sage green', '💛 Sunny yellow', '🤍 Clean white']),
    DateQuestion('misc_candle_dinner', '🕯️', 'Dinner by candlelight at…',
        ['🏠 Home', '🌳 Garden', '🏖️ Beach', '🌃 Rooftop']),
    DateQuestion('misc_fridge_note', '🧲', 'Fridge note says…', [
      '🍕 Ate your pizza!',
      '💕 Have a great day',
      '🛒 Buy milk',
      '😂 A silly doodle'
    ]),
    DateQuestion('misc_travel_mug', '☕', 'Travel mug message?', [
      '☕ But first, coffee',
      '🫖 Chai lover',
      '🌙 Night owl fuel',
      '😴 Do not disturb'
    ]),
    DateQuestion('misc_umbrella_color', '☂️', 'Umbrella color?',
        ['🔴 Red', '🟡 Yellow', '⚫ Black', '🌈 Rainbow']),
    DateQuestion('misc_bike_basket', '🧺', 'Bike basket holds…',
        ['💐 Flowers', '🥖 Bread', '🐶 A tiny dog', '📚 Books']),
    DateQuestion('misc_sunglass_moment', '😎', 'Coolest date moment?', [
      '😎 Sunglasses on',
      '🏍️ Scooter ride',
      '🎸 Guitar solo',
      '🏀 Perfect shot'
    ]),
    DateQuestion('misc_star_sign', '✨', 'Just for fun: which zodiac vibe?',
        ['🔥 Fire signs', '🌊 Water signs', '🌬️ Air signs', '🌍 Earth signs']),
    DateQuestion('misc_number', '🔢', 'Lucky number for our date?',
        ['3️⃣ 3', '7️⃣ 7', '9️⃣ 9', '🔟 10']),
    DateQuestion('misc_hello_line', '👋', 'Opening line on our date?', [
      '😊 "Hi, finally!"',
      '😂 A silly joke',
      '🍕 "Hungry?"',
      '🌸 A compliment'
    ]),
    DateQuestion('misc_photo_pose', '📸', 'Signature couple pose?', [
      '✌️ Peace signs',
      '🤝 Back to back',
      '🙃 Upside-down',
      '🫶 Heart hands'
    ]),
    DateQuestion('misc_dance_style', '🕺', 'Our dance style?', [
      '🐧 Penguin shuffle',
      '🪩 Disco fever',
      '💃 Bollywood moves',
      '🤖 Robot'
    ]),
    DateQuestion('misc_dream_vehicle', '🛵', 'Dream date vehicle?',
        ['🛵 Vespa', '🚐 VW van', '🛶 Gondola', '🎈 Balloon']),
    DateQuestion('misc_signature_drink', '🥤', 'Our signature drink?', [
      '🫖 Masala chai',
      '🍓 Strawberry shake',
      '🌿 Virgin mojito',
      '🧋 Bubble tea'
    ]),
    DateQuestion('misc_fave_sound', '🎵', 'Most comforting sound?', [
      '🌧️ Rain on roof',
      '🔥 Crackling fire',
      '🐈 Cat purr',
      '🌊 Ocean waves'
    ]),
    DateQuestion('misc_bucket_food', '🌎', 'Food to try abroad?', [
      '🍝 Real Italian pasta',
      '🍜 Tokyo ramen',
      '🥐 Paris croissant',
      '🌮 Mexico City tacos'
    ]),
    DateQuestion('misc_wall_clock', '🕰️', 'Time stops on our date. We…', [
      '🌅 One long sunset',
      '🍕 Eat forever',
      '💬 Talk forever',
      '💃 Dance forever'
    ]),
    DateQuestion('misc_rain_song', '🌧️', 'Monsoon song?', [
      '🎶 Barso re',
      '🌧️ Rimjhim gire sawan',
      "☔ Singin' in the Rain",
      '🎵 Make one up'
    ]),
    DateQuestion('misc_hug_type', '🫂', 'Best hug?',
        ['🐻 Bear hug', '🔙 Back hug', '🌀 Spin hug', '🤗 Quick squeeze']),
    DateQuestion('misc_rainbow_pick', '🌈', 'Pick a rainbow color',
        ['❤️ Red', '💚 Green', '💙 Blue', '💜 Violet']),
    DateQuestion('misc_moon_phase', '🌙', 'Favorite moon phase?',
        ['🌕 Full moon', '🌙 Crescent', '🌗 Half moon', '🌑 New moon stars']),
    DateQuestion('misc_wishlist', '📝', 'Couple wishlist item?', [
      '🏕️ Camping gear',
      '🎮 Two-player game',
      '📷 Instant camera',
      '🛋️ Big bean bag'
    ]),
    DateQuestion('misc_bedtime_story', '📚', 'Bedtime story genre?',
        ['🧚 Fairy tale', '👻 Mild spooky', '😂 Funny', '🌌 Space adventure']),
    DateQuestion('misc_tiny_date', '🌱', 'Smallest sweet date?', [
      '☕ Coffee on steps',
      '🍦 Shared cone',
      '🌅 Five-minute sunset',
      '📞 Long call'
    ]),
    DateQuestion('misc_outfit_swap', '🔄', 'Swap one item of clothing?',
        ['🧢 Cap', '🧥 Jacket', '🕶️ Sunglasses', '🧦 Socks']),
    DateQuestion('misc_superhero_duo', '🦸', 'Our superhero duo power?', [
      '⚡ Super speed',
      '🛡️ Shield & strength',
      '🔥 Fire & ice',
      '🧠 Brains & charm'
    ]),
    DateQuestion('misc_garden_grow', '🍅', 'Grow one thing together?',
        ['🍅 Tomatoes', '🌿 Mint', '🌻 Sunflowers', '🍓 Strawberries']),
    DateQuestion('misc_weird_food', '🤪', "Weird combo we'd try?", [
      '🍟 Fries + ice cream',
      '🍫 Chocolate + chilli',
      '🍎 Apple + PB',
      '🥭 Mango + salt'
    ]),
    DateQuestion('misc_game_show_prize', '🏆', "Grand prize we'd want?",
        ['✈️ Free trip', '🍕 Pizza for a year', '🚗 New car', '🐶 A puppy']),
    DateQuestion('misc_breakfast_bed', '🛌', 'Weekend morning menu?', [
      '🥞 Pancakes',
      '🍳 Full breakfast',
      '🫓 Chole bhature',
      '🥣 Granola bowl'
    ]),
    DateQuestion('misc_ice_breaker_q', '❓', 'Best first question?', [
      '🍕 Fave food?',
      '✈️ Dream trip?',
      '🎬 Fave movie?',
      '🐾 Cats or dogs?'
    ]),
    DateQuestion('misc_couple_hobby', '🎯', "Hobby we'd bond over?",
        ['🍳 Cooking', '🎮 Gaming', '🥾 Hiking', '📚 Reading']),
    DateQuestion('misc_sticker', '🏷️', 'Our laptop sticker?',
        ['🐱 Cat', '🍕 Pizza', '🌙 Moon', '🌵 Cactus']),
    DateQuestion('misc_mood_today', '🌤️', "If today's mood were a date…",
        ['☕ Lazy café', '🎢 Theme park', '🎬 Movie in bed', '🥾 Big hike']),
    DateQuestion('misc_last_minute', '⚡', 'Date in 30 minutes. Where?', [
      '☕ Nearest café',
      '🌳 Closest park',
      '🍦 Ice cream parlor',
      '🏠 Living room'
    ]),
    DateQuestion('misc_reunion_spot', '🔁', "Spot we'd keep returning to?", [
      '☕ Our café',
      '🌳 Our bench',
      '🍜 Our noodle place',
      '🌅 Our viewpoint'
    ]),
    DateQuestion('misc_fave_word', '💬', 'Word that sums up a good date?',
        ['✨ Spark', '😂 Giggles', '☕ Cozy', '🌙 Dreamy']),
    DateQuestion('misc_wallpaper', '📱', 'Phone wallpaper?',
        ['🌄 Nature', '🐶 Pet photo', '🌌 Space', '🎨 Abstract art']),
    DateQuestion('misc_drive_in_food', '🚗', 'Drive-in movie food?',
        ['🍔 Burgers', '🍿 Popcorn', '🌭 Hot dogs', '🥤 Shakes']),
    DateQuestion('misc_snow_globe', '🔮', 'Snow globe scene?',
        ['🏔️ Mountains', '🏙️ City', '🏠 Cottage', '🎡 Fair']),
    DateQuestion('misc_season_drink', '🍹', 'Seasonal drink?', [
      '🎃 Pumpkin spice',
      '🍋 Summer lemonade',
      '🍫 Winter cocoa',
      '🥭 Mango shake'
    ]),
    DateQuestion('misc_love_letter_seal', '✉️', 'Seal our letters with…',
        ['💋 A kiss mark', '🌸 Dried flower', '🖍️ Doodle', '🔴 Wax seal']),
    DateQuestion('misc_balloon', '🎈', 'Balloon color for our date?',
        ['❤️ Red', '💛 Yellow', '💜 Purple', '🤍 White']),
    DateQuestion('misc_meeting_story', '💬', 'How we tell our story?', [
      '😂 Hilarious version',
      '🌹 Romantic version',
      '📱 "We met on an app"',
      '🎭 Totally made up'
    ]),
    DateQuestion('misc_cartoon_couple', '🧸', "Cartoon couple we're like?", [
      '🐭 Mickey & Minnie',
      '🐼 Panda pals',
      '👹 Shrek & Fiona',
      '🐧 Penguin pair'
    ]),
    DateQuestion('misc_hammock', '🌴', 'Hammock for…',
        ['😴 Naps', '📖 Reading', '🌌 Stargazing', '💬 Talking']),
    DateQuestion('misc_lucky_charm', '🍀', 'Date-night lucky charm?',
        ['🍀 Clover', '🪙 Coin', '🧿 Evil-eye bead', '🧦 Lucky socks']),
    DateQuestion('misc_umbrella_drink', '🍍', 'Tropical drink?', [
      '🥥 Coconut water',
      '🍍 Pineapple juice',
      '🥭 Mango smoothie',
      '🍓 Strawberry slush'
    ]),
    DateQuestion('misc_dinner_music_live', '🎻', 'Live performer at dinner?',
        ['🎻 Violinist', '🎸 Guitarist', '🎹 Pianist', '🪕 Folk singer']),
    DateQuestion('misc_best_compliment', '🥰', "Compliment we'd love?", [
      '😂 "You\'re so funny"',
      '🧠 "You\'re so smart"',
      '😊 "Great smile"',
      '💖 "You\'re kind"'
    ]),
    DateQuestion(
        'misc_shared_secret',
        '🤫',
        'Couple\'s secret code word for "let\'s leave"?',
        ['🍍 Pineapple', '🦒 Giraffe', '🌮 Taco', '🎈 Balloon']),
    DateQuestion('misc_arcade_prize', '🧸', 'Arcade ticket prize?', [
      '🧸 Giant teddy',
      '🍬 Candy pile',
      '🕶️ Toy sunglasses',
      '🪀 Glow yo-yo'
    ]),
    DateQuestion('misc_city_sound', '🏙️', 'City sound we love?', [
      '🚋 Tram bells',
      '🎷 Street musician',
      '☕ Café chatter',
      '🌧️ Rain on streets'
    ]),
    DateQuestion('misc_sweet_morning', '🌅', 'Good-morning text?', [
      '☀️ "Rise & shine!"',
      '☕ Coffee emoji',
      '🎵 A song link',
      '🥱 "5 more mins"'
    ]),
    DateQuestion(
        'misc_together_skill',
        '🧑‍🤝‍🧑',
        "Skill we'd master as a team?",
        ['🍳 Cooking', '💃 Salsa', '🧩 Puzzles', '🏸 Badminton doubles']),
    DateQuestion('misc_rainy_movie', '🎬', 'Rainy-day movie?',
        ['💕 Rom-com', '🧙 Fantasy', '🔍 Mystery', '🎞️ Old classic']),
    DateQuestion('misc_holiday_card', '💌', 'Holiday card style?', [
      '📸 Our photo',
      '🎨 Hand-drawn',
      '😂 Funny meme',
      '🌟 Glittery classic'
    ]),
    DateQuestion('misc_signature_snack', '🥨', 'Couple snack combo?', [
      '🫖 Chai & samosa',
      '🍿 Popcorn & cola',
      '🍫 Chocolate & coffee',
      '🍪 Cookies & milk'
    ]),
    DateQuestion('misc_pinky_date', '📅', 'Future date we promise?', [
      '🌌 See northern lights',
      '🏔️ Snow trip',
      '🏖️ Beach sunrise',
      '🎡 Fair on a full moon'
    ]),
    DateQuestion('misc_end_wish', '🌠', 'Last wish of the night?', [
      '🔁 Do it again',
      '🌅 Stay till sunrise',
      '🍦 One more dessert',
      '📸 One more photo'
    ]),
    DateQuestion('misc_window_view', '🪟', 'View from our dream window?',
        ['🌊 Ocean', '🏔️ Snowy peaks', '🏙️ City lights', '🌳 Big garden']),
    DateQuestion('misc_sunday_market', '🧺', 'Sunday market haul?',
        ['🍓 Fresh berries', '🌻 Flowers', '🥖 Warm bread', '🍯 Local honey']),
    DateQuestion('misc_walk_snack', '🥜', 'Walking snack?',
        ['🥜 Roasted peanuts', '🌽 Bhutta', '🍦 Softy', '🥨 Pretzel']),
    DateQuestion('misc_tea_party', '🫖', 'Fancy tea party menu?',
        ['🥪 Tiny sandwiches', '🧁 Scones', '🍰 Cake stand', '🍪 Biscuits']),
    DateQuestion('misc_big_win', '🎉', 'We get great news. We celebrate with…',
        ['🍕 Pizza party', '💃 Dance', '🍰 Cake', '🚗 Road trip']),
  ];
}

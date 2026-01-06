const Map<String, List<String>> hobbyCategories = {
  'Muzika': [
    'Gitara',
    'Klavir',
    'Violina',
    'Bubnjevi',
    'Bas gitara',
    'Saksofon',
    'Truba',
    'Flauta',
    'Harmonika',
    'Klarinet',
    'Pevač',
    'DJ',
    'Produkcija muzike',
    'Komponovanje',
    'Dirigovanje',
    'Rep',
    'Pop',
    'Rock',
    'Metal',
    'Jazz',
    'Bluz',
    'Elektronska muzika',
    'Narodna muzika',
    'Klasična muzika',
    'Ostalo',
  ],

  'Sport': [
    'Fudbal',
    'Košarka',
    'Odbojka',
    'Rukomet',
    'Tenis',
    'Stoni tenis',
    'Badminton',
    'Plivanje',
    'Atletika',
    'Trčanje',
    'Biciklizam',
    'Planinarenje',
    'Fitness',
    'Bodybuilding',
    'Crossfit',
    'Joga',
    'Pilates',
    'Borilačke veštine',
    'Karate',
    'Džudo',
    'Tekvondo',
    'Boks',
    'Kickboxing',
    'MMA',
    'Skijanje',
    'Snowboard',
    'Skateboarding',
    'Parkour',
    'Ostalo',
  ],

  'Umetnost': [
    'Crtanje',
    'Slikanje',
    'Ilustracija',
    'Digitalna umetnost',
    'Grafički dizajn',
    'Vajarstvo',
    'Keramika',
    'Fotografija',
    'Video umetnost',
    'Strip',
    'Kaligrafija',
    'Tetoviranje',
    'Murali',
    'Ostalo',
  ],

  'Tehnologija': [
    'Programiranje',
    'Web development',
    'Mobile development',
    'Game development',
    'AI / Mašinsko učenje',
    'Robotika',
    'Elektronika',
    'Arduino',
    'Raspberry Pi',
    '3D štampa',
    '3D modelovanje',
    'CAD dizajn',
    'Cyber security',
    'Linux',
    'Windows administracija',
    'Mreže',
    'IoT',
    'Ostalo',
  ],

  'Igre': [
    'Video igre',
    'PC igre',
    'Konzolne igre',
    'Mobilne igre',
    'Retro igre',
    'Board games',
    'Karte',
    'Šah',
    'Dungeons & Dragons',
    'Esport',
    'Speedrunning',
    'Game modding',
    'Ostalo',
  ],

  'Kreativno pisanje': [
    'Poezija',
    'Kratke priče',
    'Romani',
    'Scenario',
    'Blogovanje',
    'Novinarstvo',
    'Pisanje pesama',
    'Copywriting',
    'Tehničko pisanje',
    'Ostalo',
  ],

  'Film i mediji': [
    'Režija',
    'Scenaristika',
    'Gluma',
    'Kinematografija',
    'Montaža',
    'Produkcija',
    'YouTube',
    'Streaming',
    'Podcast',
    'TikTok',
    'Ostalo',
  ],

  'Edukacija': [
    'Matematika',
    'Fizika',
    'Hemija',
    'Biologija',
    'Informatika',
    'Jezici',
    'Psihologija',
    'Filozofija',
    'Istorija',
    'Geografija',
    'Tutorstvo',
    'Ostalo',
  ],

  'Priroda': [
    'Planinarenje',
    'Kampovanje',
    'Ribolov',
    'Lov',
    'Botanika',
    'Zoologija',
    'Astronomija',
    'Ekologija',
    'Ostalo',
  ],

  'Život i stil': [
    'Kuvanje',
    'Peciva',
    'Veganska kuhinja',
    'Roštilj',
    'Fotografija hrane',
    'Putovanja',
    'Backpacking',
    'Minimalizam',
    'Moda',
    'Šminka',
    'Frizure',
    'Samorazvoj',
    'Meditacija',
    'Ostalo',
  ],

  // NEW ADDITIONS:

  'Ples': [
    'Balet',
    'Savremeni ples',
    'Latino plesovi',
    'Salsa',
    'Bachata',
    'Tango',
    'Flamenco',
    'Hip-hop',
    'Breakdance',
    'Jazz ples',
    'Irske igre',
    'Narodne igre',
    'Ples na štiklama',
    'Zumba',
    'Ostalo',
  ],

  'Ručni radovi': [
    'Izrada nakita',
    'Heđbording',
    'Vezenje',
    'Pletanje',
    'Heklanje',
    'Izrada sveća',
    'Izrada sapuna',
    'Izrada poklona',
    'Papir mache',
    'Origami',
    'Izrada ukrasa',
    'Izrada kožnih predmeta',
    'Drvodeljstvo',
    'Ostalo',
  ],

  'Automobili i motori': [
    'Tuning',
    'Restauracija automobila',
    'Drifting',
    'Off-road',
    'Motociklizam',
    'Kvadovi',
    'Skuteri',
    'Automehanika',
    'Detailing',
    'Automobilska fotografija',
    'Ostalo',
  ],

  'Avijacija i more': [
    'Avijacija',
    'Jedrilice',
    'Padobranstvo',
    'Modeli aviona',
    'Jedrenje',
    'Ronjenje',
    'Surfovanje',
    'Veslanje',
    'Jet ski',
    'Brodski modeli',
    'Ostalo',
  ],

  'Kolekcionarstvo': [
    'Marke',
    'Novčići',
    'Knjige',
    'Vinil ploče',
    'CD kolekcije',
    'Filmovi',
    'Figure',
    'Automobili (modeli)',
    'Avioni (modeli)',
    'Antikviteti',
    'Umjetničke slike',
    'Ostalo',
  ],

  'Domaćinstvo': [
    'Vrtlarstvo',
    'Baštovanstvo',
    'Uređenje enterijera',
    'Dekorisanje',
    'Renoviranje',
    'DIY projekti',
    'Pčelarstvo',
    'Kovanje',
    'Stolarija',
    'Ostalo',
  ],

  'Ljubimci': [
    'Pseći sportovi',
    'Mačke',
    'Ptice',
    'Akvaristika',
    'Terraristika',
    'Konji',
    'Psi',
    'Glišteri',
    'Reptili',
    'Ostalo',
  ],

  'Modelarstvo': [
    'Modeli aviona',
    'Modeli automobila',
    'Modeli brodova',
    'Modeli vozova',
    'Modeli zgrada',
    'Modeli tenkova',
    'RC modeli',
    'Modeli u plastici',
    'Modeli u drvetu',
    'Ostalo',
  ],

  'Parapsihologija': [
    'Astrologija',
    'Tarot karte',
    'Numerologija',
    'Šamanizam',
    'Kartomantija',
    'Meditacija',
    'Joga',
    'Čitanje iz kafe',
    'Ostalo',
  ],

  'Misterije i paranormalno': [
    'Istorijske misterije',
    'Paranormalne pojave',
    'UFO istraživanja',
    'Kriptozoologija',
    'Arheologija',
    'Istraživanje duhova',
    'Ostalo',
  ],

  'Društvene veštine': [
    'Debatovanje',
    'Publiko govorništvo',
    'Vodjenje timova',
    'Konfliktnost',
    'Poslovni networking',
    'Mentorstvo',
    'Ostalo',
  ],

  'Gastronomija': [
    'Degustacija vina',
    'Degustacija piva',
    'Sirovi sir',
    'Čokolada',
    'Kafa',
    'Čaj',
    'Začini',
    'Poslastičarstvo',
    'Ostalo',
  ],

  'Finansije i investiranje': [
    'Berza',
    'Kriptovalute',
    'Nekretnine',
    'Osobne finansije',
    'Investiciono planiranje',
    'Porezi',
    'Ostalo',
  ],

  'Preživljavanje': [
    'Survival',
    'Bushcraft',
    'Orijentacija u prirodi',
    'Prva pomoć',
    'Šivanje opreme',
    'Lov i ribolov za preživljavanje',
    'Ostalo',
  ],

  'Biljke i lekovito bilje': [
    'Herbalizam',
    'Aromaterapija',
    'Uzgoj lekovitog bilja',
    'Fitoterapija',
    'Sušenje biljaka',
    'Čajevi od bilja',
    'Ostalo',
  ],

  'Metalfabrikacija': [
    'Kovanje',
    'Varioc',
    'Bravarstvo',
    'Mašinska obrada',
    'CNC mašine',
    '3D štampa u metalu',
    'Ostalo',
  ],

  'Kostimografija i šminka': [
    'Šminka za pozorište',
    'Šminka za film',
    'Izrada kostima',
    'Maskiranje',
    'Prostetička šminka',
    'Ostalo',
  ],

  'Pogrebne usluge': [
    'Tanatopraksija',
    'Floristika za sahrane',
    'Organizacija sahrana',
    'Pogrebni rituali',
    'Ostalo',
  ],

  'Veterinarska medicina': [
    'Neg životinja',
    'Prva pomoć za životinje',
    'Uzgoj životinja',
    'Ostalo',
  ],

  'Muzički instrumenti izrade': [
    'Izrada gitar',
    'Izrada violina',
    'Izrada bubnjeva',
    'Izrada frula',
    'Ostalo',
  ],

  'Papir i knjigoveštvo': [
    'Papir mache',
    'Izrada papira',
    'Knjigoveštvo',
    'Restauracija knjiga',
    'Ostalo',
  ],

  'Navigacija': [
    'Astronomska navigacija',
    'GPS navigacija',
    'Kompas i mape',
    'Ostalo',
  ],

  'Vazduhoplovstvo': [
    'Pilotiranje',
    'Avionska mehanika',
    'Padobranstvo',
    'Ostalo',
  ],

  'Podvodne aktivnosti': [
    'Ronjenje',
    'Snorkeling',
    'Podvodni ribolov',
    'Podvodna fotografija',
    'Ostalo',
  ],

  'Zimske aktivnosti': [
    'Skijanje',
    'Snowboarding',
    'Klizanje',
    'Sankanje',
    'Ostalo',
  ],

  'Ljetne aktivnosti': [
    'Plivanje',
    'Surfovanje',
    'Pješačenje',
    'Kampovanje',
    'Ostalo',
  ],

  'Kozmetologija': [
    'Šminka',
    'Nega lica',
    'Nega tela',
    'Manikir',
    'Pedikir',
    'Depilacija',
    'Ostalo',
  ],

  'Frizerstvo': [
    'Muško šišanje',
    'Žensko šišanje',
    'Farbanje kose',
    'Pletenice',
    'Ostalo',
  ],

  'Masaze': [
    'Sportske masaze',
    'Relaks masaze',
    'Tajlandske masaze',
    'Shiatsu',
    'Ostalo',
  ],

  'Meditacija i duhovnost': [
    'Meditacija',
    'Joga',
    'Duhovne prakse',
    'Čakre',
    'Ostalo',
  ],

  'Putovanja': [
    'Backpacking',
    'Turističko putovanje',
    'Rad na putu',
    'Putnička fotografija',
    'Ostalo',
  ],

  'Jezičko učenje': [
    'Engleski',
    'Nemački',
    'Francuski',
    'Španski',
    'Italijanski',
    'Ruski',
    'Kineski',
    'Japanski',
    'Ostalo',
  ],

  'Politika': [
    'Debatovanje',
    'Politička analiza',
    'Volontiranje u politici',
    'Ostalo',
  ],

  'Pravne nauke': [
    'Pravna istorija',
    'Pravna teorija',
    'Pravna pismenost',
    'Ostalo',
  ],

  'Ekonomija': [
    'Makroekonomija',
    'Mikroekonomija',
    'Poslovna ekonomija',
    'Ostalo',
  ],

  'Sociologija': [
    'Društvene promene',
    'Kultura',
    'Socijalne institucije',
    'Ostalo',
  ],

  'Antropologija': [
    'Kulturna antropologija',
    'Arheologija',
    'Etnologija',
    'Ostalo',
  ],

  'Geologija': [
    'Mineralogija',
    'Paleontologija',
    'Vulkanologija',
    'Ostalo',
  ],

  'Meteorologija': [
    'Praćenje vremena',
    'Vremenske pojave',
    'Klimatske promene',
    'Ostalo',
  ],

  'Oceanografija': [
    'Morske struje',
    'Morska biologija',
    'Morska geologija',
    'Ostalo',
  ],

  'Kozmologija': [
    'Astronomija',
    'Astrofizika',
    'Kosmologija',
    'Ostalo',
  ],

  'Matematičke nauke': [
    'Algebra',
    'Geometrija',
    'Kalkulus',
    'Statistika',
    'Ostalo',
  ],

  'Hemijske nauke': [
    'Organska hemija',
    'Neorganska hemija',
    'Fizička hemija',
    'Biokemija',
    'Ostalo',
  ],

  'Fizičke nauke': [
    'Mehanika',
    'Termodinamika',
    'Elektromagnetizam',
    'Kvantna fizika',
    'Ostalo',
  ],

  'Biološke nauke': [
    'Botanika',
    'Zoologija',
    'Mikrobiologija',
    'Genetika',
    'Ostalo',
  ],

  'Medicinske nauke': [
    'Anatomija',
    'Fiziologija',
    'Patologija',
    'Farmakologija',
    'Ostalo',
  ],

  'Inženjerstvo': [
    'Mašinsko inženjerstvo',
    'Elektrotehnika',
    'Građevinarstvo',
    'Hemijsko inženjerstvo',
    'Ostalo',
  ],

  'Arhitektura': [
    'Dizajn zgrada',
    'Urbanizam',
    'Enterijer',
    'Historijska arhitektura',
    'Ostalo',
  ],

  'Dizajn': [
    'Grafički dizajn',
    'Industrijski dizajn',
    'Modni dizajn',
    'Dizajn interijera',
    'Ostalo',
  ],

  'Marketing': [
    'Digitalni marketing',
    'Content marketing',
    'Social media marketing',
    'SEO',
    'Ostalo',
  ],

  'Menadžment': [
    'Projekt menadžment',
    'Ljudski resursi',
    'Operativni menadžment',
    'Strateški menadžment',
    'Ostalo',
  ],

  'Preduzetništvo': [
    'Pokretanje biznisa',
    'Poslovni planovi',
    'Startapovi',
    'Finansiranje',
    'Ostalo',
  ],

  'Karijera i razvoj': [
    'CV pisanje',
    'Intervju veštine',
    'Networking',
    'Mentorstvo',
    'Ostalo',
  ],

  'Odnosi': [
    'Porodični odnosi',
    'Partnerski odnosi',
    'Prijateljski odnosi',
    'Radni odnosi',
    'Ostalo',
  ],

  'Mentalno zdravlje': [
    'Psihologija',
    'Psihoterapija',
    'Samopomoć',
    'Mindfulness',
    'Ostalo',
  ],

  'Fizičko zdravlje': [
    'Trening',
    'Ishrana',
    'San',
    'Prevencija bolesti',
    'Ostalo',
  ],

  'Bezbednost': [
    'Lična bezbednost',
    'Kućna bezbednost',
    'Cyber bezbednost',
    'Prva pomoć',
    'Ostalo',
  ],

  'Zaštita životne sredine': [
    'Reciklaža',
    'Održivi razvoj',
    'Čuvanje energije',
    'Čuvanje vode',
    'Ostalo',
  ],

  'Volontiranje': [
    'Humanitarni rad',
    'Zaštita životinja',
    'Zaštita životne sredine',
    'Podrška zajednici',
    'Ostalo',
  ],

  'Društvene aktivnosti': [
    'Klubovi',
    'Udruženja',
    'Dogadjaji',
    'Mitingi',
    'Ostalo',
  ],

  'Kulturna istorija': [
    'Istorija umetnosti',
    'Istorija muzike',
    'Istorija filma',
    'Istorija književnosti',
    'Ostalo',
  ],

  'Religija i duhovnost': [
    'Hrišćanstvo',
    'Islam',
    'Budizam',
    'Judaizam',
    'Ostalo',
  ],

  'Filozofija': [
    'Etika',
    'Metafizika',
    'Logika',
    'Politička filozofija',
    'Ostalo',
  ],

  'Etika': [
    'Bioetika',
    'Poslovna etika',
    'Medicinska etika',
    'Etika u tehnologiji',
    'Ostalo',
  ],

  'Logika': [
    'Formalna logika',
    'Matematička logika',
    'Filosofska logika',
    'Ostalo',
  ],

  'Retorika': [
    'Publiko govorništvo',
    'Debatovanje',
    'Pisanje govora',
    'Ubeđivanje',
    'Ostalo',
  ],

  'Književnost': [
    'Čitanje',
    'Pisanje',
    'Književna kritika',
    'Književna teorija',
    'Ostalo',
  ],

  'Poezija': [
    'Pisanje pesama',
    'Čitanje poezije',
    'Poetske forme',
    'Poetski prevod',
    'Ostalo',
  ],

  'Drama': [
    'Pisanje drama',
    'Gluma',
    'Režija',
    'Scenografija',
    'Ostalo',
  ],

  'Pripovedanje': [
    'Pisanje priča',
    'Usmeno pripovedanje',
    'Podcast pripovedanje',
    'Pripovedanje za decu',
    'Ostalo',
  ],

  'Biografije': [
    'Pisanje biografija',
    'Čitanje biografija',
    'Autobiografije',
    'Memorari',
    'Ostalo',
  ],

  'Istorijske studije': [
    'Antika',
    'Srednji vek',
    'Renesansa',
    'Moderno doba',
    'Ostalo',
  ],

  'Arheološke studije': [
    'Iskopavanja',
    'Analiza artefakata',
    'Restauracija',
    'Arheološke metode',
    'Ostalo',
  ],

  'Genealogija': [
    'Istraživanje porodične istorije',
    'Stablo porodice',
    'DNA istraživanje',
    'Arhivski rad',
    'Ostalo',
  ],

  'Heraldika': [
    'Grbovi',
    'Zastave',
    'Pečati',
    'Simbolika',
    'Ostalo',
  ],

  'Numizmatika': [
    'Novčići',
    'Medalje',
    'Banknote',
    'Numizmatička istorija',
    'Ostalo',
  ],

  'Filatelija': [
    'Marke',
    'Filatelistička istorija',
    'Kolekcionarstvo marki',
    'Filatelistička literatura',
    'Ostalo',
  ],

  'Vojna istorija': [
    'Bitke',
    'Oružje',
    'Strategije',
    'Vojne ličnosti',
    'Ostalo',
  ],

  'Politička istorija': [
    'Revolucije',
    'Ratovi',
    'Političke partije',
    'Političke ideologije',
    'Ostalo',
  ],

  'Ekonomska istorija': [
    'Trgovina',
    'Industrijska revolucija',
    'Ekonomske krize',
    'Ekonomski sistemi',
    'Ostalo',
  ],

  'Kulturna antropologija': [
    'Rituali',
    'Tradicije',
    'Običaji',
    'Kulturni simboli',
    'Ostalo',
  ],

  'Lingvistika': [
    'Gramatika',
    'Fonetika',
    'Semantika',
    'Pragmatika',
    'Ostalo',
  ],

  'Prevodenje': [
    'Književno prevodenje',
    'Tehničko prevodenje',
    'Simultan prevod',
    'Prevodioci',
    'Ostalo',
  ],

  'Jezici naroda': [
    'Srpski',
    'Hrvatski',
    'Bosanski',
    'Crnogorski',
    'Ostalo',
  ],

  'Jezici manjina': [
    'Romski',
    'Mađarski',
    'Slovački',
    'Rusinski',
    'Ostalo',
  ],

  'Jezici migranata': [
    'Arapski',
    'Kineski',
    'Turksi',
    'Albanski',
    'Ostalo',
  ],

  'Jezici znakova': [
    'Srpski znakovni jezik',
    'Američki znakovni jezik',
    'Britanski znakovni jezik',
    'Medunarodni znakovni jezik',
    'Ostalo',
  ],

  'Braille pismo': [
    'Braille čitanje',
    'Braille pisanje',
    'Braille prevod',
    'Braille tehnologija',
    'Ostalo',
  ],

  'Kriptografija': [
    'Šifrovanje',
    'Dešifrovanje',
    'Kriptografski algoritmi',
    'Kvantna kriptografija',
    'Ostalo',
  ],

  'Kriptovalute': [
    'Bitcoin',
    'Ethereum',
    'Blockchain',
    'NFT',
    'Ostalo',
  ],

  'Mrežne tehnologije': [
    'LAN',
    'WAN',
    'VPN',
    'Cloud computing',
    'Ostalo',
  ],

  'Operativni sistemi': [
    'Windows',
    'Linux',
    'macOS',
    'Android',
    'Ostalo',
  ],

  'Baze podataka': [
    'SQL',
    'NoSQL',
    'MySQL',
    'PostgreSQL',
    'Ostalo',
  ],

  'Razvoj softvera': [
    'Frontend',
    'Backend',
    'Fullstack',
    'DevOps',
    'Ostalo',
  ],

  'Testiranje softvera': [
    'Manualno testiranje',
    'Automatsko testiranje',
    'Unit testovi',
    'Integracioni testovi',
    'Ostalo',
  ],

  'UI/UX dizajn': [
    'User Interface',
    'User Experience',
    'Wireframing',
    'Prototyping',
    'Ostalo',
  ],

  'Produkcija muzike': [
    'Miksovanje',
    'Mastering',
    'Sound design',
    'Sinteza',
    'Ostalo',
  ],

  'Audio inženjerstvo': [
    'Snimanje',
    'Editovanje',
    'Post-produkcija',
    'Spatial audio',
    'Ostalo',
  ],

  'Video produkcija': [
    'Snimanje videa',
    'Editovanje videa',
    'Color grading',
    'Visual effects',
    'Ostalo',
  ],

  'Animacija': [
    '2D animacija',
    '3D animacija',
    'Stop motion',
    'Motion graphics',
    'Ostalo',
  ],

  'VFX': [
    'Compositing',
    'CGI',
    'Matte painting',
    'Simulacije',
    'Ostalo',
  ],

  'Game design': [
    'Level design',
    'Character design',
    'Game mechanics',
    'Narrative design',
    'Ostalo',
  ],

  'Esports': [
    'CS:GO',
    'Dota 2',
    'League of Legends',
    'Valorant',
    'Ostalo',
  ],

  'Streaming': [
    'Twitch',
    'YouTube Gaming',
    'Facebook Gaming',
    'Mixer',
    'Ostalo',
  ],

  'Content creation': [
    'Vlogovi',
    'Tutoriali',
    'Reviews',
    'Unboxing',
    'Ostalo',
  ],

  'Social media': [
    'Instagram',
    'Twitter',
    'Facebook',
    'LinkedIn',
    'Ostalo',
  ],

  'Blogovanje': [
    'Lični blog',
    'Poslovni blog',
    'Tematiski blog',
    'Gostopisanje',
    'Ostalo',
  ],

  'Podcasting': [
    'Planiranje podcasta',
    'Snimanje podcasta',
    'Editovanje podcasta',
    'Promocija podcasta',
    'Ostalo',
  ],

  'Videografija': [
    'Drone snimanje',
    'Timelapse',
    'Hyperlapse',
    'Slow motion',
    'Ostalo',
  ],

  'Fotografija': [
    'Portretna fotografija',
    'Pejzažna fotografija',
    'Makro fotografija',
    'Noćna fotografija',
    'Ostalo',
  ],

  'Fotoeditovanje': [
    'Photoshop',
    'Lightroom',
    'GIMP',
    'Affinity Photo',
    'Ostalo',
  ],

  'Videoeditovanje': [
    'Premiere Pro',
    'DaVinci Resolve',
    'Final Cut Pro',
    'After Effects',
    'Ostalo',
  ],

  '3D modelovanje': [
    'Blender',
    'Maya',
    '3ds Max',
    'ZBrush',
    'Ostalo',
  ],

  '3D štampa': [
    'FDM štampa',
    'SLA štampa',
    'Modelovanje za štampu',
    'Post-procesiranje',
    'Ostalo',
  ],

  'Lasersko graviranje': [
    'Graviranje drveta',
    'Graviranje metala',
    'Graviranje stakla',
    'Graviranje plastike',
    'Ostalo',
  ],

  'CNC mašine': [
    'CNC glodanje',
    'CNC tokarenje',
    'CNC rezanje',
    'CAM programiranje',
    'Ostalo',
  ],

  'Robotika': [
    'Autonomni roboti',
    'Industrijski roboti',
    'Roboti za edukaciju',
    'Roboti za kućnu upotrebu',
    'Ostalo',
  ],

  'Dronovi': [
    'Fotografija dronom',
    'Video dronom',
    'Trke dronova',
    'Programiranje dronova',
    'Ostalo',
  ],

  'RC modeli': [
    'RC automobili',
    'RC avioni',
    'RC helikopteri',
    'RC brodovi',
    'Ostalo',
  ],

  'Elektronika': [
    'Lepljenje kola',
    'Projektovanje kola',
    'Električna merenja',
    'Popravka elektronskih uređaja',
    'Ostalo',
  ],

  'Arduino': [
    'Arduino programiranje',
    'Arduino projekti',
    'Arduino senzori',
    'Arduino aktvatori',
    'Ostalo',
  ],

  'Raspberry Pi': [
    'Raspberry Pi projekti',
    'Raspberry Pi programiranje',
    'Raspberry Pi server',
    'Raspberry Pi medij centar',
    'Ostalo',
  ],

  'IoT': [
    'Pametna kuća',
    'Pametni gradovi',
    'Industrijski IoT',
    'IoT senzori',
    'Ostalo',
  ],

  'Kvantna računarstva': [
    'Kvantni algoritmi',
    'Kvantno programiranje',
    'Kvantna simulacija',
    'Kvantna kriptografija',
    'Ostalo',
  ],

  'Biotehnologija': [
    'Genetski inženjering',
    'Biomedicina',
    'Bioinformatika',
    'Bioprocesno inženjerstvo',
    'Ostalo',
  ],

  'Nanotehnologija': [
    'Nanomaterijali',
    'Nanoelektronika',
    'Nanomedicina',
    'Nanosenzori',
    'Ostalo',
  ],

  'Kvantna fizika': [
    'Kvantna mehanika',
    'Kvantna teorija polja',
    'Kvantna gravitacija',
    'Kvantna informacija',
    'Ostalo',
  ],

  'Astrofizika': [
    'Kosmologija',
    'Astronomija',
    'Planetarna nauka',
    'Zvezdana evolucija',
    'Ostalo',
  ],

  'Kompleksne nauke': [
    'Složeni sistemi',
    'Mrežne nauke',
    'Samoorganizacija',
    'Emergentno ponašanje',
    'Ostalo',
  ],

  'Kognitivne nauke': [
    'Kognitivna psihologija',
    'Kognitivna neuro nauka',
    'Kognitivna lingvistika',
    'Kognitivna antropologija',
    'Ostalo',
  ],

  'Neuro nauka': [
    'Neuropsihologija',
    'Neurobiologija',
    'Neurohirurgija',
    'Neuromarketing',
    'Ostalo',
  ],

  'Psihologija': [
    'Klinicka psihologija',
    'Razvojna psihologija',
    'Socijalna psihologija',
    'Eksperimentalna psihologija',
    'Ostalo',
  ]
};
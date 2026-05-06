/// Dati geografici: Italia e Svizzera
/// Regioni/Cantoni, Province/Distretti e Città
class Locations {
  /// Paesi supportati
  static const List<String> countries = ['Italia', 'Svizzera'];

  /// Regioni italiane
  static const List<String> italianRegions = [
    'Abruzzo',
    'Basilicata',
    'Calabria',
    'Campania',
    'Emilia-Romagna',
    'Friuli-Venezia Giulia',
    'Lazio',
    'Liguria',
    'Lombardia',
    'Marche',
    'Molise',
    'Piemonte',
    'Puglia',
    'Sardegna',
    'Sicilia',
    'Toscana',
    'Trentino-Alto Adige',
    'Umbria',
    'Valle d\'Aosta',
    'Veneto',
  ];

  /// Cantoni svizzeri
  static const List<String> swissCantons = [
    'Argovia',
    'Appenzello Esterno',
    'Appenzello Interno',
    'Basilea Campagna',
    'Basilea Città',
    'Berna',
    'Friburgo',
    'Ginevra',
    'Glarona',
    'Grigioni',
    'Giura',
    'Lucerna',
    'Neuchâtel',
    'Nidvaldo',
    'Obvaldo',
    'San Gallo',
    'Sciaffusa',
    'Soletta',
    'Svitto',
    'Turgovia',
    'Ticino',
    'Uri',
    'Vallese',
    'Vaud',
    'Zugo',
    'Zurigo',
  ];

  /// Province italiane per regione
  static const Map<String, List<String>> italianProvincesByRegion = {
    'Abruzzo': ['Chieti', 'L\'Aquila', 'Pescara', 'Teramo'],
    'Basilicata': ['Matera', 'Potenza'],
    'Calabria': ['Catanzaro', 'Cosenza', 'Crotone', 'Reggio Calabria', 'Vibo Valentia'],
    'Campania': ['Avellino', 'Benevento', 'Caserta', 'Napoli', 'Salerno'],
    'Emilia-Romagna': ['Bologna', 'Ferrara', 'Forlì-Cesena', 'Modena', 'Parma', 'Piacenza', 'Ravenna', 'Reggio Emilia', 'Rimini'],
    'Friuli-Venezia Giulia': ['Gorizia', 'Pordenone', 'Trieste', 'Udine'],
    'Lazio': ['Frosinone', 'Latina', 'Rieti', 'Roma', 'Viterbo'],
    'Liguria': ['Genova', 'Imperia', 'La Spezia', 'Savona'],
    'Lombardia': ['Bergamo', 'Brescia', 'Como', 'Cremona', 'Lecco', 'Lodi', 'Mantova', 'Milano', 'Monza e Brianza', 'Pavia', 'Sondrio', 'Varese'],
    'Marche': ['Ancona', 'Ascoli Piceno', 'Fermo', 'Macerata', 'Pesaro e Urbino'],
    'Molise': ['Campobasso', 'Isernia'],
    'Piemonte': ['Alessandria', 'Asti', 'Biella', 'Cuneo', 'Novara', 'Torino', 'Verbano-Cusio-Ossola', 'Vercelli'],
    'Puglia': ['Bari', 'Barletta-Andria-Trani', 'Brindisi', 'Foggia', 'Lecce', 'Taranto'],
    'Sardegna': ['Cagliari', 'Carbonia-Iglesias', 'Medio Campidano', 'Nuoro', 'Ogliastra', 'Olbia-Tempio', 'Oristano', 'Sassari'],
    'Sicilia': ['Agrigento', 'Caltanissetta', 'Catania', 'Enna', 'Messina', 'Palermo', 'Ragusa', 'Siracusa', 'Trapani'],
    'Toscana': ['Arezzo', 'Firenze', 'Grosseto', 'Livorno', 'Lucca', 'Massa-Carrara', 'Pisa', 'Pistoia', 'Prato', 'Siena'],
    'Trentino-Alto Adige': ['Bolzano', 'Trento'],
    'Umbria': ['Perugia', 'Terni'],
    'Valle d\'Aosta': ['Aosta'],
    'Veneto': ['Belluno', 'Padova', 'Rovigo', 'Treviso', 'Venezia', 'Verona', 'Vicenza'],
  };

  /// Distretti svizzeri per cantone (semplificato - principali città/distretti)
  static const Map<String, List<String>> swissDistrictsByCanton = {
    'Argovia': ['Aarau', 'Baden', 'Brugg', 'Lenzburg', 'Zofingen', 'Rheinfelden'],
    'Appenzello Esterno': ['Herisau', 'Heiden', 'Teufen'],
    'Appenzello Interno': ['Appenzello'],
    'Basilea Campagna': ['Liestal', 'Arlesheim', 'Binningen', 'Muttenz', 'Pratteln'],
    'Basilea Città': ['Basilea', 'Riehen', 'Bettingen'],
    'Berna': ['Berna', 'Biel/Bienne', 'Thun', 'Burgdorf', 'Langenthal', 'Interlaken', 'Köniz'],
    'Friburgo': ['Friburgo', 'Bulle', 'Murten', 'Romont'],
    'Ginevra': ['Ginevra', 'Carouge', 'Lancy', 'Meyrin', 'Vernier', 'Onex'],
    'Glarona': ['Glarona', 'Näfels'],
    'Grigioni': ['Coira', 'Davos', 'St. Moritz', 'Landquart', 'Ilanz', 'Poschiavo'],
    'Giura': ['Delémont', 'Porrentruy', 'Saignelégier'],
    'Lucerna': ['Lucerna', 'Emmen', 'Kriens', 'Horw', 'Sursee', 'Hochdorf'],
    'Neuchâtel': ['Neuchâtel', 'La Chaux-de-Fonds', 'Le Locle', 'Boudry'],
    'Nidvaldo': ['Stans', 'Hergiswil', 'Buochs'],
    'Obvaldo': ['Sarnen', 'Engelberg', 'Kerns'],
    'San Gallo': ['San Gallo', 'Rapperswil-Jona', 'Wil', 'Gossau', 'Buchs', 'Altstätten'],
    'Sciaffusa': ['Sciaffusa', 'Neuhausen am Rheinfall', 'Stein am Rhein'],
    'Soletta': ['Soletta', 'Olten', 'Grenchen'],
    'Svitto': ['Svitto', 'Einsiedeln', 'Freienbach', 'Küssnacht'],
    'Turgovia': ['Frauenfeld', 'Kreuzlingen', 'Arbon', 'Romanshorn', 'Weinfelden'],
    'Ticino': ['Lugano', 'Bellinzona', 'Locarno', 'Mendrisio', 'Chiasso', 'Ascona', 'Biasca'],
    'Uri': ['Altdorf', 'Andermatt', 'Erstfeld'],
    'Vallese': ['Sion', 'Sierre', 'Martigny', 'Monthey', 'Briga-Glis', 'Visp', 'Zermatt'],
    'Vaud': ['Losanna', 'Montreux', 'Vevey', 'Nyon', 'Morges', 'Yverdon-les-Bains', 'Renens'],
    'Zugo': ['Zugo', 'Baar', 'Cham', 'Steinhausen'],
    'Zurigo': ['Zurigo', 'Winterthur', 'Uster', 'Dübendorf', 'Dietikon', 'Wetzikon', 'Kloten', 'Bülach'],
  };

  /// Comuni italiani per provincia
  static const Map<String, List<String>> italianCitiesByProvince = {
    'Chieti': ['Chieti', 'Francavilla al Mare', 'Lanciano', 'Ortona', 'Vasto'],
    'L\'Aquila': ['L\'Aquila', 'Avezzano', 'Sulmona'],
    'Pescara': ['Pescara', 'Montesilvano', 'Spoltore'],
    'Teramo': ['Teramo', 'Giulianova', 'Roseto degli Abruzzi'],
    'Matera': ['Matera', 'Pisticci', 'Policoro'],
    'Potenza': ['Potenza', 'Melfi', 'Lavello'],
    'Catanzaro': ['Catanzaro', 'Lamezia Terme', 'Soverato'],
    'Cosenza': ['Cosenza', 'Rende', 'Rossano', 'Corigliano Calabro'],
    'Crotone': ['Crotone', 'Cirò Marina'],
    'Reggio Calabria': ['Reggio Calabria', 'Gioia Tauro', 'Palmi'],
    'Vibo Valentia': ['Vibo Valentia', 'Tropea'],
    'Avellino': ['Avellino', 'Ariano Irpino'],
    'Benevento': ['Benevento'],
    'Caserta': ['Caserta', 'Aversa', 'Marcianise'],
    'Napoli': ['Napoli', 'Acerra', 'Afragola', 'Arzano', 'Bacoli', 'Castellammare di Stabia', 'Ercolano', 'Giugliano in Campania', 'Marano di Napoli', 'Pomigliano d\'Arco', 'Portici', 'Pozzuoli', 'Torre del Greco'],
    'Salerno': ['Salerno', 'Battipaglia', 'Cava de\' Tirreni', 'Eboli', 'Nocera Inferiore'],
    'Bologna': ['Bologna', 'Imola', 'Casalecchio di Reno', 'San Lazzaro di Savena'],
    'Ferrara': ['Ferrara', 'Cento'],
    'Forlì-Cesena': ['Forlì', 'Cesena', 'Cesenatico'],
    'Modena': ['Modena', 'Carpi', 'Sassuolo'],
    'Parma': ['Parma', 'Fidenza'],
    'Piacenza': ['Piacenza', 'Castel San Giovanni'],
    'Ravenna': ['Ravenna', 'Faenza', 'Lugo'],
    'Reggio Emilia': ['Reggio Emilia', 'Correggio', 'Guastalla'],
    'Rimini': ['Rimini', 'Riccione', 'Cattolica'],
    'Gorizia': ['Gorizia', 'Monfalcone'],
    'Pordenone': ['Pordenone', 'Azzano Decimo'],
    'Trieste': ['Trieste', 'Muggia'],
    'Udine': ['Udine', 'Codroipo', 'Cividale del Friuli'],
    'Frosinone': ['Frosinone', 'Cassino', 'Sora'],
    'Latina': ['Latina', 'Aprilia', 'Cisterna di Latina', 'Fondi', 'Terracina'],
    'Rieti': ['Rieti'],
    'Roma': ['Roma', 'Anzio', 'Ciampino', 'Civitavecchia', 'Fiumicino', 'Guidonia Montecelio', 'Ladispoli', 'Nettuno', 'Pomezia', 'Tivoli', 'Velletri'],
    'Viterbo': ['Viterbo', 'Civita Castellana'],
    'Genova': ['Genova', 'Chiavari', 'Rapallo', 'Sestri Levante'],
    'Imperia': ['Imperia', 'Sanremo', 'Ventimiglia'],
    'La Spezia': ['La Spezia', 'Sarzana'],
    'Savona': ['Savona', 'Albenga', 'Loano'],
    'Bergamo': ['Bergamo', 'Treviglio', 'Seriate'],
    'Brescia': ['Brescia', 'Desenzano del Garda', 'Lumezzane'],
    'Como': ['Como', 'Cantù', 'Erba'],
    'Cremona': ['Cremona', 'Crema'],
    'Lecco': ['Lecco', 'Merate'],
    'Lodi': ['Lodi', 'Codogno'],
    'Mantova': ['Mantova', 'Castiglione delle Stiviere'],
    'Milano': ['Milano', 'Abbiategrasso', 'Bollate', 'Cinisello Balsamo', 'Cologno Monzese', 'Corsico', 'Gorgonzola', 'Legnano', 'Magenta', 'Melzo', 'Rho', 'Sesto San Giovanni', 'Trezzano sul Naviglio'],
    'Monza e Brianza': ['Monza', 'Desio', 'Lissone', 'Seregno'],
    'Pavia': ['Pavia', 'Vigevano', 'Voghera'],
    'Sondrio': ['Sondrio', 'Bormio'],
    'Varese': ['Varese', 'Busto Arsizio', 'Gallarate', 'Saronno'],
    'Ancona': ['Ancona', 'Jesi', 'Senigallia'],
    'Ascoli Piceno': ['Ascoli Piceno', 'San Benedetto del Tronto'],
    'Fermo': ['Fermo', 'Porto San Giorgio'],
    'Macerata': ['Macerata', 'Civitanova Marche'],
    'Pesaro e Urbino': ['Pesaro', 'Fano', 'Urbino'],
    'Campobasso': ['Campobasso', 'Termoli'],
    'Isernia': ['Isernia', 'Venafro'],
    'Alessandria': ['Alessandria', 'Casale Monferrato', 'Novi Ligure', 'Tortona'],
    'Asti': ['Asti'],
    'Biella': ['Biella'],
    'Cuneo': ['Cuneo', 'Alba', 'Bra', 'Fossano', 'Mondovì', 'Saluzzo'],
    'Novara': ['Novara', 'Arona', 'Borgomanero'],
    'Torino': ['Torino', 'Chieri', 'Chivasso', 'Collegno', 'Ivrea', 'Moncalieri', 'Nichelino', 'Orbassano', 'Pinerolo', 'Rivoli', 'Settimo Torinese', 'Venaria Reale'],
    'Verbano-Cusio-Ossola': ['Verbania', 'Domodossola', 'Omegna'],
    'Vercelli': ['Vercelli', 'Borgosesia'],
    'Bari': ['Bari', 'Acquaviva delle Fonti', 'Altamura', 'Bitonto', 'Conversano', 'Gioia del Colle', 'Gravina in Puglia', 'Modugno', 'Molfetta', 'Monopoli', 'Triggiano'],
    'Barletta-Andria-Trani': ['Barletta', 'Andria', 'Trani'],
    'Brindisi': ['Brindisi', 'Fasano', 'Francavilla Fontana', 'Mesagne'],
    'Foggia': ['Foggia', 'Cerignola', 'Manfredonia', 'San Severo'],
    'Lecce': ['Lecce', 'Galatina', 'Nardò'],
    'Taranto': ['Taranto', 'Grottaglie', 'Manduria', 'Martina Franca'],
    'Cagliari': ['Cagliari', 'Assemini', 'Quartu Sant\'Elena', 'Selargius'],
    'Carbonia-Iglesias': ['Carbonia', 'Iglesias'],
    'Medio Campidano': ['Sanluri', 'Villacidro'],
    'Nuoro': ['Nuoro', 'Siniscola'],
    'Ogliastra': ['Tortolì'],
    'Olbia-Tempio': ['Olbia', 'Tempio Pausania'],
    'Oristano': ['Oristano'],
    'Sassari': ['Sassari', 'Alghero', 'Porto Torres'],
    'Agrigento': ['Agrigento', 'Canicattì', 'Licata', 'Sciacca'],
    'Caltanissetta': ['Caltanissetta', 'Gela', 'Niscemi'],
    'Catania': ['Catania', 'Acireale', 'Adrano', 'Belpasso', 'Caltagirone', 'Giarre', 'Misterbianco', 'Paternò'],
    'Enna': ['Enna', 'Piazza Armerina'],
    'Messina': ['Messina', 'Barcellona Pozzo di Gotto', 'Milazzo', 'Taormina'],
    'Palermo': ['Palermo', 'Bagheria', 'Carini', 'Monreale', 'Partinico', 'Termini Imerese'],
    'Ragusa': ['Ragusa', 'Modica', 'Vittoria'],
    'Siracusa': ['Siracusa', 'Augusta', 'Avola', 'Noto'],
    'Trapani': ['Trapani', 'Alcamo', 'Castelvetrano', 'Marsala', 'Mazara del Vallo'],
    'Arezzo': ['Arezzo', 'Cortona', 'Montevarchi', 'Sansepolcro'],
    'Firenze': ['Firenze', 'Campi Bisenzio', 'Empoli', 'Scandicci', 'Sesto Fiorentino'],
    'Grosseto': ['Grosseto', 'Follonica', 'Orbetello'],
    'Livorno': ['Livorno', 'Cecina', 'Piombino'],
    'Lucca': ['Lucca', 'Viareggio', 'Capannori'],
    'Massa-Carrara': ['Massa', 'Carrara'],
    'Pisa': ['Pisa', 'Cascina', 'Pontedera', 'San Giuliano Terme'],
    'Pistoia': ['Pistoia', 'Montecatini Terme', 'Quarrata'],
    'Prato': ['Prato', 'Montemurlo'],
    'Siena': ['Siena', 'Colle di Val d\'Elsa', 'Poggibonsi'],
    'Bolzano': ['Bolzano', 'Merano', 'Bressanone', 'Brunico'],
    'Trento': ['Trento', 'Rovereto', 'Pergine Valsugana', 'Riva del Garda'],
    'Perugia': ['Perugia', 'Assisi', 'Bastia Umbra', 'Città di Castello', 'Corciano', 'Foligno', 'Gubbio', 'Spoleto'],
    'Terni': ['Terni', 'Orvieto'],
    'Aosta': ['Aosta'],
    'Belluno': ['Belluno', 'Feltre'],
    'Padova': ['Padova', 'Abano Terme', 'Cittadella', 'Este', 'Monselice'],
    'Rovigo': ['Rovigo', 'Adria'],
    'Treviso': ['Treviso', 'Castelfranco Veneto', 'Conegliano', 'Montebelluna', 'Vittorio Veneto'],
    'Venezia': ['Venezia', 'Chioggia', 'Mestre', 'Mirano', 'San Donà di Piave'],
    'Verona': ['Verona', 'Bussolengo', 'Legnago', 'San Bonifacio', 'Villafranca di Verona'],
    'Vicenza': ['Vicenza', 'Arzignano', 'Bassano del Grappa', 'Schio', 'Thiene'],
  };

  /// Città svizzere per distretto (coincidono con i distretti per semplicità)
  static const Map<String, List<String>> swissCitiesByDistrict = {
    'Aarau': ['Aarau'],
    'Baden': ['Baden', 'Wettingen', 'Ennetbaden'],
    'Brugg': ['Brugg', 'Windisch'],
    'Lenzburg': ['Lenzburg'],
    'Zofingen': ['Zofingen'],
    'Rheinfelden': ['Rheinfelden'],
    'Herisau': ['Herisau'],
    'Heiden': ['Heiden'],
    'Teufen': ['Teufen'],
    'Appenzello': ['Appenzello'],
    'Liestal': ['Liestal'],
    'Arlesheim': ['Arlesheim'],
    'Binningen': ['Binningen'],
    'Muttenz': ['Muttenz'],
    'Pratteln': ['Pratteln'],
    'Basilea': ['Basilea'],
    'Riehen': ['Riehen'],
    'Bettingen': ['Bettingen'],
    'Berna': ['Berna', 'Ostermundigen', 'Zollikofen'],
    'Biel/Bienne': ['Biel/Bienne', 'Nidau'],
    'Thun': ['Thun', 'Steffisburg'],
    'Burgdorf': ['Burgdorf'],
    'Langenthal': ['Langenthal'],
    'Interlaken': ['Interlaken', 'Unterseen', 'Matten bei Interlaken'],
    'Köniz': ['Köniz', 'Liebefeld'],
    'Friburgo': ['Friburgo', 'Villars-sur-Glâne', 'Givisiez'],
    'Bulle': ['Bulle'],
    'Murten': ['Murten'],
    'Romont': ['Romont'],
    'Ginevra': ['Ginevra', 'Plainpalais', 'Eaux-Vives'],
    'Carouge': ['Carouge'],
    'Lancy': ['Lancy', 'Petit-Lancy', 'Grand-Lancy'],
    'Meyrin': ['Meyrin'],
    'Vernier': ['Vernier'],
    'Onex': ['Onex'],
    'Glarona': ['Glarona'],
    'Näfels': ['Näfels'],
    'Coira': ['Coira'],
    'Davos': ['Davos', 'Davos Platz', 'Davos Dorf'],
    'St. Moritz': ['St. Moritz', 'Celerina', 'Pontresina'],
    'Landquart': ['Landquart', 'Igis'],
    'Ilanz': ['Ilanz'],
    'Poschiavo': ['Poschiavo'],
    'Delémont': ['Delémont'],
    'Porrentruy': ['Porrentruy'],
    'Saignelégier': ['Saignelégier'],
    'Lucerna': ['Lucerna', 'Littau'],
    'Emmen': ['Emmen'],
    'Kriens': ['Kriens'],
    'Horw': ['Horw'],
    'Sursee': ['Sursee'],
    'Hochdorf': ['Hochdorf'],
    'Neuchâtel': ['Neuchâtel'],
    'La Chaux-de-Fonds': ['La Chaux-de-Fonds'],
    'Le Locle': ['Le Locle'],
    'Boudry': ['Boudry'],
    'Stans': ['Stans'],
    'Hergiswil': ['Hergiswil'],
    'Buochs': ['Buochs'],
    'Sarnen': ['Sarnen'],
    'Engelberg': ['Engelberg'],
    'Kerns': ['Kerns'],
    'San Gallo': ['San Gallo'],
    'Rapperswil-Jona': ['Rapperswil-Jona'],
    'Wil': ['Wil'],
    'Gossau': ['Gossau'],
    'Buchs': ['Buchs'],
    'Altstätten': ['Altstätten'],
    'Sciaffusa': ['Sciaffusa'],
    'Neuhausen am Rheinfall': ['Neuhausen am Rheinfall'],
    'Stein am Rhein': ['Stein am Rhein'],
    'Soletta': ['Soletta'],
    'Olten': ['Olten'],
    'Grenchen': ['Grenchen'],
    'Svitto': ['Svitto'],
    'Einsiedeln': ['Einsiedeln'],
    'Freienbach': ['Freienbach', 'Pfäffikon SZ'],
    'Küssnacht': ['Küssnacht am Rigi'],
    'Frauenfeld': ['Frauenfeld'],
    'Kreuzlingen': ['Kreuzlingen'],
    'Arbon': ['Arbon'],
    'Romanshorn': ['Romanshorn'],
    'Weinfelden': ['Weinfelden'],
    'Lugano': ['Lugano', 'Paradiso', 'Massagno', 'Viganello'],
    'Bellinzona': ['Bellinzona', 'Giubiasco'],
    'Locarno': ['Locarno', 'Muralto', 'Minusio'],
    'Mendrisio': ['Mendrisio'],
    'Chiasso': ['Chiasso'],
    'Ascona': ['Ascona'],
    'Biasca': ['Biasca'],
    'Altdorf': ['Altdorf'],
    'Andermatt': ['Andermatt'],
    'Erstfeld': ['Erstfeld'],
    'Sion': ['Sion'],
    'Sierre': ['Sierre'],
    'Martigny': ['Martigny'],
    'Monthey': ['Monthey'],
    'Briga-Glis': ['Briga-Glis', 'Briga', 'Glis'],
    'Visp': ['Visp'],
    'Zermatt': ['Zermatt'],
    'Losanna': ['Losanna', 'Pully', 'Lutry'],
    'Montreux': ['Montreux', 'Territet', 'Clarens'],
    'Vevey': ['Vevey', 'Corseaux'],
    'Nyon': ['Nyon'],
    'Morges': ['Morges'],
    'Yverdon-les-Bains': ['Yverdon-les-Bains'],
    'Renens': ['Renens'],
    'Zugo': ['Zugo'],
    'Baar': ['Baar'],
    'Cham': ['Cham'],
    'Steinhausen': ['Steinhausen'],
    'Zurigo': ['Zurigo', 'Oerlikon', 'Altstetten', 'Wiedikon'],
    'Winterthur': ['Winterthur', 'Töss', 'Seen'],
    'Uster': ['Uster'],
    'Dübendorf': ['Dübendorf'],
    'Dietikon': ['Dietikon'],
    'Wetzikon': ['Wetzikon'],
    'Kloten': ['Kloten'],
    'Bülach': ['Bülach'],
  };

  // ========== METODI HELPER ==========

  /// Ottieni regioni/cantoni per paese
  static List<String> getRegionsByCountry(String? country) {
    if (country == null || country.isEmpty) return [];
    if (country == 'Italia') return italianRegions;
    if (country == 'Svizzera') return swissCantons;
    return [];
  }

  /// Ottieni province/distretti per regione/cantone
  static List<String> getProvincesByRegion(String? region, {String? country}) {
    if (region == null || region.isEmpty) return [];
    
    // Prova prima Italia
    if (italianProvincesByRegion.containsKey(region)) {
      return italianProvincesByRegion[region] ?? [];
    }
    // Poi Svizzera
    if (swissDistrictsByCanton.containsKey(region)) {
      return swissDistrictsByCanton[region] ?? [];
    }
    return [];
  }

  /// Ottieni città per provincia/distretto
  static List<String> getCitiesByProvince(String? province, {String? country}) {
    if (province == null || province.isEmpty) return [];
    
    // Prova prima Italia
    if (italianCitiesByProvince.containsKey(province)) {
      return italianCitiesByProvince[province] ?? [];
    }
    // Poi Svizzera
    if (swissCitiesByDistrict.containsKey(province)) {
      return swissCitiesByDistrict[province] ?? [];
    }
    return [];
  }

  /// Ottieni tutte le regioni (Italia + Svizzera)
  static List<String> getAllRegions() {
    return [...italianRegions, ...swissCantons]..sort();
  }

  /// Ottieni tutte le province (Italia + Svizzera)
  static List<String> getAllProvinces() {
    final all = <String>{};
    for (final provinces in italianProvincesByRegion.values) {
      all.addAll(provinces);
    }
    for (final districts in swissDistrictsByCanton.values) {
      all.addAll(districts);
    }
    return all.toList()..sort();
  }

  /// Ottieni tutte le città (Italia + Svizzera)
  static List<String> getAllCities() {
    final all = <String>{};
    for (final cities in italianCitiesByProvince.values) {
      all.addAll(cities);
    }
    for (final cities in swissCitiesByDistrict.values) {
      all.addAll(cities);
    }
    return all.toList()..sort();
  }

  /// Determina il paese da una regione/cantone
  static String? getCountryByRegion(String? region) {
    if (region == null || region.isEmpty) return null;
    if (italianRegions.contains(region)) return 'Italia';
    if (swissCantons.contains(region)) return 'Svizzera';
    return null;
  }

  /// Label per regione in base al paese
  static String getRegionLabel(String? country) {
    if (country == 'Svizzera') return 'Cantone';
    return 'Regione';
  }

  /// Label per provincia in base al paese
  static String getProvinceLabel(String? country) {
    if (country == 'Svizzera') return 'Distretto';
    return 'Provincia';
  }
}

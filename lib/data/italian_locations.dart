/// Dati geografici italiani: Regioni, Province e Comuni (capoluoghi + principali città)
class ItalianLocations {
  static const List<String> regions = [
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

  static const Map<String, List<String>> provincesByRegion = {
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

  /// Comuni principali (capoluoghi + città più popolose)
  static const Map<String, List<String>> citiesByProvince = {
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

  /// Ottieni tutte le province in ordine alfabetico
  static List<String> getAllProvinces() {
    final all = <String>{};
    for (final provinces in provincesByRegion.values) {
      all.addAll(provinces);
    }
    final list = all.toList()..sort();
    return list;
  }

  /// Ottieni tutti i comuni in ordine alfabetico
  static List<String> getAllCities() {
    final all = <String>{};
    for (final cities in citiesByProvince.values) {
      all.addAll(cities);
    }
    final list = all.toList()..sort();
    return list;
  }

  /// Ottieni province filtrate per regione
  static List<String> getProvincesByRegion(String? region) {
    if (region == null || region.isEmpty) return getAllProvinces();
    return provincesByRegion[region] ?? [];
  }

  /// Ottieni comuni filtrati per provincia
  static List<String> getCitiesByProvince(String? province) {
    if (province == null || province.isEmpty) return getAllCities();
    return citiesByProvince[province] ?? [];
  }
}

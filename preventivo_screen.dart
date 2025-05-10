// --- START OF COMPLETE SCRIPT ---
// File: lib/preventivo_screen.dart (v23 - Finale con JSON Esterno per Tariffe e API Key, UI Completa)

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Per Uint8List
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // Non più usato per Maps API Key
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';

// Enum per Città
enum Citta { roma, milano }

// --- Costanti NON TARIFFARIE ---
// IVA_PERCENT e COSTO_VITTO_ALLOGGIO ora vengono da JSON
const String ROMA_TERMINI_ADDRESS = "Piazza dei Cinquecento, Roma RM, Italia";
const String MILANO_CADORNA_ADDRESS = "Piazzale Luigi Cadorna, Milano MI, Italia";

const String DEFAULT_TARIFF_ASSET_PATH = 'assets/config/tariffe.json'; // Fallback locale
const String CACHED_TARIFF_FILENAME = 'cached_tariffe.json';
// --- Fine Costanti ---

class PreventivoScreen extends StatefulWidget {
  const PreventivoScreen({super.key});
  @override
  _PreventivoScreenState createState() => _PreventivoScreenState();
}

class _PreventivoScreenState extends State<PreventivoScreen> {
  // ----- STATO DEL WIDGET -----
  final _clienteController = TextEditingController();
  final _partenzaController = TextEditingController();
  final _destinazioneController = TextEditingController();
  final _noteExtraController = TextEditingController();
  final _importoExtraController = TextEditingController();
  final _scontoController = TextEditingController();
  final List<TextEditingController> _tappeController = [];
  String? _veicoloSelezionato = "BERLINA";
  bool _noAvvicinamento = false; bool _noRientro = false; bool _disposizioneAttiva = false;
  int _oreExtraCentro = 0; int _oreExtraFuori = 0; bool _blocco3hCentro = false; bool _blocco3hFuori = false;
  bool _vittoAlloggioAttivo = false; bool _servizioNotturnoAttivo = false; bool _costiExtraAttivi = false;
  bool _supplementoFestivo50 = false; bool _supplementoFestivo30 = false; bool _isAltaStagioneActive = false;
  bool _isAltissimaStagioneActive = false;
  bool _applicaIva = true;
  Citta _cittaSelezionata = Citta.roma;
  bool _partenzaFuoriCentro = false;
  bool _destinazioneFuoriCentro = false;
  List<bool> _tappeFuoriCentro = [];
  bool _isLoadingDistance = false; double? _calculatedKm; String? _errorMessage; Map<String, dynamic>? _calculationResultData;

  // --- STATI PER CONFIGURAZIONI CARICATE ---
  bool _isLoadingConfigs = true;
  String? _configsErrorMessage;
  String? _loadedGoogleMapsApiKey;

  Map<String, double> _tariffeFisseCaricate = {};
  Map<String, List<double>> _tariffeOrarieCaricate = {};
  Map<String, double> _tariffeKmDispoCaricate = {};
  Map<String, double> _tariffeKmTransferCaricate = {};
  double _ivaPercentCaricata = 10.0; // Default
  double _costoVittoCaricato = 150.0; // Default
  double _altaStagionePercentCaricata = 20.0; // Default
  double _altissimaStagionePercentCaricata = 50.0; // Default

  // ----- FINE STATO -----

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  // --- FUNZIONE PER CARICARE CONFIGURAZIONI (Tariffe e API Key) ---
  Future<void> _loadConfigs() async {
    if (!mounted) return;
    setState(() { _isLoadingConfigs = true; _configsErrorMessage = null; });
    print("Avvio caricamento configurazioni (tariffe e API key)...");

    String? loadedJsonString;
    String loadedSource = "Sconosciuta";

    // -------- INSERISCI QUI IL TUO URL GIST RAW (corto e stabile) --------
    const String remoteConfigsUrl = "https://gist.githubusercontent.com/leorm1110/8e97f11ecd597c3df9d83379ea96a778/raw/tariffe.json"; // <-- SOSTITUISCI QUESTO!
    // --------------------------------------------------------------------
    try {
      String cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      String urlWithCacheBuster = "$remoteConfigsUrl?$cacheBuster";
      print("Tentativo download da (con cache buster): $urlWithCacheBuster");
      final response = await http.get(Uri.parse(urlWithCacheBuster)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        loadedJsonString = response.body;
        loadedSource = "URL Remoto";
        print("Download configurazioni da URL remoto riuscito.");
        await _saveConfigsToCache(loadedJsonString);
      } else {
        print("Download fallito (Status: ${response.statusCode}). Provo cache locale.");
        throw Exception("HTTP Error ${response.statusCode}");
      }
    } catch (e) {
      print("Errore download configurazioni: $e. Tentativo caricamento da cache locale...");
      try {
        loadedJsonString = await _loadConfigsFromCache();
        if (loadedJsonString != null) {
          loadedSource = "Cache Locale";
          print("Caricamento da cache locale riuscito.");
        } else {
           print("Cache locale non trovata/vuota. Provo dagli asset.");
           throw Exception("Cache vuota");
        }
      } catch (eCache) {
        print("Errore caricamento da cache: $eCache. Tentativo caricamento da asset...");
        try {
          loadedJsonString = await rootBundle.loadString(DEFAULT_TARIFF_ASSET_PATH);
          loadedSource = "Asset Default";
          print("Caricamento da asset di default riuscito.");
        } catch (eAsset) {
          print("ERRORE CRITICO: Impossibile caricare configurazioni: $eAsset");
          if (!mounted) return;
          setState(() {
            _configsErrorMessage = "Impossibile caricare le configurazioni da qualsiasi fonte.";
            _isLoadingConfigs = false;
          });
          return;
        }
      }
    }

    if (loadedJsonString != null) {
      try {
        final Map<String, dynamic> decodedData = jsonDecode(loadedJsonString);
        print('>>>>>> JSON Decodificato da ($loadedSource): $decodedData');
        _parseAndSetConfigs(decodedData);
        print("Configurazioni da '$loadedSource' processate con successo.");
        if(loadedSource != "URL Remoto" && _configsErrorMessage == null) {
             _configsErrorMessage = "Tariffe caricate da $loadedSource (potrebbero non essere aggiornate).";
        }
      } catch (eParse) {
        print("ERRORE parsing JSON da '$loadedSource': $eParse");
         if (!mounted) return;
         setState(() { _configsErrorMessage = "Errore nel formato delle configurazioni ($loadedSource): $eParse"; });
      }
    }

    if (mounted) {
      setState(() { _isLoadingConfigs = false; });
    }
  }

  Future<void> _saveConfigsToCache(String jsonString) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$CACHED_TARIFF_FILENAME');
      await file.writeAsString(jsonString);
      print("Configurazioni salvate nella cache locale: ${file.path}");
    } catch (e) { print("Errore salvataggio configurazioni in cache: $e"); }
  }

  Future<String?> _loadConfigsFromCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$CACHED_TARIFF_FILENAME');
      if (await file.exists()) { print("Cache locale trovata: ${file.path}"); return await file.readAsString(); }
      print("Cache locale non trovata."); return null;
    } catch (e) { print("Errore lettura configurazioni da cache: $e"); return null; }
  }

  void _parseAndSetConfigs(Map<String, dynamic> data) {
      final Map<String, dynamic> apiKeysMap = Map<String, dynamic>.from(data['api_keys'] ?? {});
      _loadedGoogleMapsApiKey = apiKeysMap['Maps'] as String?; // DEVE ESSERE 'Maps' nel JSON
      if (_loadedGoogleMapsApiKey == null || _loadedGoogleMapsApiKey!.isEmpty) {
        print("ATTENZIONE: Chiave API Google Maps non trovata o vuota nel JSON!");
        _configsErrorMessage = (_configsErrorMessage ?? "") + " Chiave API Google Maps mancante nel JSON.";
      } else {
        print("Chiave API Google Maps caricata: ...${_loadedGoogleMapsApiKey!.substring(_loadedGoogleMapsApiKey!.length - 6)}");
      }

      final Map<String, dynamic> rawFixed = Map<String, dynamic>.from(data['tariffe fisse'] ?? {}); // USA SPAZIO
      final Map<String, double> fixed = {};
      rawFixed.forEach((key, value) { fixed[key] = (value as num?)?.toDouble() ?? 0.0; });
      _tariffeFisseCaricate = fixed;

      final Map<String, dynamic> rawHourly = Map<String, dynamic>.from(data['tariffe_orarie'] ?? {});
      final Map<String, List<double>> hourly = {};
      rawHourly.forEach((key, value) {
        if (value is List && value.length == 2) {
          final double? val1 = (value[0] as num?)?.toDouble(); final double? val2 = (value[1] as num?)?.toDouble();
          if (val1 != null && val2 != null) { hourly[key] = [val1, val2]; }
          else { print("WARN: Valori non validi in array tariffe_orarie[$key]"); }
        } else { print("WARN: Formato non valido per tariffe_orarie[$key]"); }
      });
      _tariffeOrarieCaricate = hourly;

      final Map<String, dynamic> rawKmDispo = Map<String, dynamic>.from(data['tariffe_km_dispo'] ?? {});
      _tariffeKmDispoCaricate = rawKmDispo.map((key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0.0));
      final Map<String, dynamic> rawKmTransfer = Map<String, dynamic>.from(data['tariffe_km_transfer'] ?? {});
      _tariffeKmTransferCaricate = rawKmTransfer.map((key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0.0));

      final Map<String, dynamic> rawAltriCosti = Map<String, dynamic>.from(data['altri_costi'] ?? {});
      _ivaPercentCaricata = (rawAltriCosti['IVA_PERCENT'] as num?)?.toDouble() ?? 10.0;
      _costoVittoCaricato = (rawAltriCosti['COSTO_VITTO_ALLOGGIO'] as num?)?.toDouble() ?? 150.0;
      _altaStagionePercentCaricata = (rawAltriCosti['ALTA_STAGione_PERCENT'] as num?)?.toDouble() ?? 20.0; // Default 20% se non trovato
      _altissimaStagionePercentCaricata = (rawAltriCosti['ALTISSIMA_STAGIONE_PERCENT'] as num?)?.toDouble() ?? 50.0; // Default 50% se non trovato
      print("Valori Caricati da JSON -> IVA: ${_ivaPercentCaricata.toStringAsFixed(1)}%, Vitto: ${_costoVittoCaricato.toStringAsFixed(2)}, AltaStag: ${_altaStagionePercentCaricata.toStringAsFixed(1)}%, AltissimaStag: ${_altissimaStagionePercentCaricata.toStringAsFixed(1)}%");
  }

  // ----- METODI HELPER UI -----
  void _aggiungiTappa() { setState(() { _tappeController.add(TextEditingController()); _tappeFuoriCentro.add(false); }); }
  void _rimuoviTappa(int index) { if (index >= 0 && index < _tappeController.length) { _tappeController[index].dispose(); setState(() { _tappeController.removeAt(index); if (index < _tappeFuoriCentro.length) { _tappeFuoriCentro.removeAt(index); } }); } }
  void _showVehicleDialog() { FocusScope.of(context).unfocus(); showDialog( context: context, builder: (BuildContext dialogContext) { return SimpleDialog( title: const Text('Seleziona Veicolo'), children: <String>['BERLINA', 'VAN 7 PAX', 'VAN 8 PAX'].map((String value) { return SimpleDialogOption( onPressed: () { setState(() { _veicoloSelezionato = value; }); Navigator.pop(dialogContext); }, child: Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(value), ), ); }).toList(), ); }, ); }
  Widget _buildHourSelector(String label, int currentValue, ValueChanged<int> onChanged) { return Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text(label), Row( children: [ IconButton( icon: Icon(Icons.remove_circle_outline), iconSize: 20, tooltip: 'Diminuisci ore', onPressed: () { if (currentValue > 0) { onChanged(currentValue - 1); } }, constraints: BoxConstraints(), padding: EdgeInsets.symmetric(horizontal: 8), ), Text('$currentValue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), IconButton( icon: Icon(Icons.add_circle_outline), iconSize: 20, tooltip: 'Aumenta ore', onPressed: () => onChanged(currentValue + 1), constraints: BoxConstraints(), padding: EdgeInsets.symmetric(horizontal: 8), ), ], ), ], ); }

  // ----- METODO CHIAMATA API DIRECTIONS -----
  Future<Map<String, dynamic>> _getRouteDetails({ required String origin, required String destination, List<String>? waypoints }) async {
    final apiKey = _loadedGoogleMapsApiKey;
    if (apiKey == null || apiKey.isEmpty) { return {'success': false, 'message': 'Chiave API non caricata o non configurata nel JSON'}; }
    final String originAddr = origin.trim(); final String destinationAddr = destination.trim();
    if (originAddr.isEmpty || destinationAddr.isEmpty) { return {'success': false, 'message': 'Origine/Destinazione vuote per API'};}
    String waypointsParam = (waypoints != null && waypoints.isNotEmpty) ? 'waypoints=' + Uri.encodeComponent('optimize:true|${waypoints.join('|')}') : '';
    final String baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
    final String params = 'origin=${Uri.encodeComponent(originAddr)}&destination=${Uri.encodeComponent(destinationAddr)}${waypointsParam.isNotEmpty ? '&$waypointsParam' : ''}&mode=driving&units=metric&region=it&key=$apiKey';
    final Uri requestUrl = Uri.parse('$baseUrl?$params');
    print('Richiesta Directions API: $requestUrl');
    try {
      final response = await http.get(requestUrl).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        if (decodedResponse['status'] == 'OK') { int totalDistanceMeters = 0; if (decodedResponse['routes'] != null && decodedResponse['routes'].isNotEmpty) { for (var leg in decodedResponse['routes'][0]['legs']) { totalDistanceMeters += (leg['distance']?['value'] as int? ?? 0); } } double totalDistanceKm = totalDistanceMeters / 1000.0; return {'success': true, 'distance_km': totalDistanceKm}; }
        else { String errMsg = decodedResponse['error_message'] ?? 'API Error: ${decodedResponse['status']}'; print('Errore API Directions: ${decodedResponse['status']} - $errMsg'); return {'success': false, 'message': 'Errore Google Maps (${decodedResponse['status']}).'}; }
      } else { print('Errore HTTP: ${response.statusCode}'); return {'success': false, 'message': 'Errore di rete (${response.statusCode}).'}; }
    } catch (e) { print('Eccezione API Directions: $e'); return {'success': false, 'message': 'Errore di connessione o timeout.'}; }
  }

  // ----- Funzione Geocoding per Arricchire l'Indirizzo -----
  Future<String> _getVerifiedAddress(String address) async {
    final String initialAddress = address.trim();
    if (initialAddress.isEmpty) return "";
    String addrLower = initialAddress.toLowerCase();
    if (addrLower.contains("roma") || addrLower.contains("milano")) { print("GeoVerify: Indirizzo contiene già città -> $initialAddress"); return initialAddress; }
    final apiKey = _loadedGoogleMapsApiKey;
    if (apiKey == null || apiKey.isEmpty) { print("[GeoVerify Error] API Key non caricata"); return initialAddress; }
    final String baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
    final String params = 'address=${Uri.encodeComponent(initialAddress)}&language=it&region=it&key=$apiKey';
    final Uri requestUrl = Uri.parse('$baseUrl?$params');
    print('Richiesta Geocoding API per Verifica: $requestUrl');
    try {
      final response = await http.get(requestUrl).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        if (decodedResponse['status'] == 'OK' && decodedResponse['results'] != null && (decodedResponse['results'] as List).isNotEmpty) {
          final result = decodedResponse['results'][0];
          final String? formattedAddress = result['formatted_address'] as String?;
          if (formattedAddress != null) { print("GeoVerify: Indirizzo verificato -> $formattedAddress"); return formattedAddress; }
        } else { print("GeoVerify API Status: ${decodedResponse['status']}"); }
      } else { print("GeoVerify HTTP Error: ${response.statusCode}"); }
    } catch (e) { print("GeoVerify Exception: $e"); }
    print("GeoVerify: Fallito, uso indirizzo originale -> $initialAddress");
    return initialAddress;
  }

  // ----- Logica Identificazione Zona -----
  String _getZoneCode(String verifiedAddress, bool isFuoriCentro) {
    if (isFuoriCentro) { print("Zone Check: Checkbox 'Fuori Centro' attivo -> ALTRO"); return "ALTRO"; }
    if (verifiedAddress.isEmpty) return "ALTRO";
    String addrLower = verifiedAddress.toLowerCase();
    print("Zone Check: Checkbox OFF, Analizzo indirizzo verificato '$addrLower'");
    if (addrLower.contains("fiumicino") && (addrLower.contains("aeroporto") || addrLower.contains("airport"))) return "FCO";
    if (addrLower.contains(" fco ") || addrLower == "fco") return "FCO";
    if (addrLower.contains("ciampino") && (addrLower.contains("aeroporto") || addrLower.contains("airport"))) return "CIA";
    if (addrLower.contains(" cia ") || addrLower == "cia") return "CIA";
    if (addrLower.contains("civitavecchia")) return "CIV";
    if (addrLower.contains("linate")) return "LIN";
    if (addrLower.contains("malpensa")) return "MXP";
    if (addrLower.contains("orio al serio") || (addrLower.contains("bergamo") && addrLower.contains("aeroporto"))) return "BGY";
    if (addrLower.contains("termini") || addrLower.contains("cadorna")) return "CENTRO";
    if (addrLower.contains("roma") || addrLower.contains("milano")) { print("Zone Check: Trovato 'roma' o 'milano' -> CENTRO"); return "CENTRO"; }
    print("Zone Check: Nessuna keyword specifica trovata -> ALTRO");
    return "ALTRO";
  }

  // Helper calcolo orario
  double _calcolaCostoOrarioDispoZona(int oreExtraInput, String veicolo, String zonaTariffaOraria, bool applicaBlocco, List<String> debugSteps) {
      String tariffZone = (zonaTariffaOraria == "CENTRO") ? "CENTRO" : "FUORI";
      String tariffaKey = "$veicolo|$tariffZone";
      List<double>? tariffe = _tariffeOrarieCaricate[tariffaKey];
      if (tariffe == null || tariffe.length < 2) { debugSteps.add("ERRORE: Tariffe orarie ($tariffaKey) non caricate o malformattate."); return 0.0; }
      double tariffaOraBlocco = tariffe[0]; double tariffaOraExtra = tariffe[1]; int oreExtraFatturabili = oreExtraInput; double costoBlocco = 0.0; double costoExtra = 0.0; String debugPrefix = "Calc Dispo [$zonaTariffaOraria]:"; if (applicaBlocco) { costoBlocco = tariffaOraBlocco * 3.0; debugSteps.add("$debugPrefix Blocco ATTIVO -> Costo Blocco (3h * ${tariffaOraBlocco.toStringAsFixed(2)} €/h): ${costoBlocco.toStringAsFixed(2)} €"); if (oreExtraFatturabili > 0) { costoExtra = oreExtraFatturabili * tariffaOraExtra; debugSteps.add("$debugPrefix Ore EXTRA AGGIUNTIVE ({$oreExtraFatturabili}h * ${tariffaOraExtra.toStringAsFixed(2)} €/h): +${costoExtra.toStringAsFixed(2)} €"); } else { debugSteps.add("$debugPrefix Nessuna Ora EXTRA aggiuntiva al blocco."); } } else { if (oreExtraFatturabili > 0) { costoExtra = oreExtraFatturabili * tariffaOraExtra; debugSteps.add("$debugPrefix Blocco NON ATTIVO -> Costo Ore Extra ({$oreExtraFatturabili}h * ${tariffaOraExtra.toStringAsFixed(2)} €/h): ${costoExtra.toStringAsFixed(2)} €"); } else { debugSteps.add("$debugPrefix Blocco NON ATTIVO & Ore Extra 0 -> Costo Orario = 0.00 €"); } } double costoTotaleZona = costoBlocco + costoExtra; debugSteps.add("$debugPrefix -> Costo Totale Orario Zona: ${costoTotaleZona.toStringAsFixed(2)} €"); return costoTotaleZona;
  }

  // --- START PART 3 (Finale con Nuove Stagioni) ---
// File: lib/preventivo_screen.dart
// (Questo blocco inizia con _performCalculationLogic e finisce con dispose())

  // ----- Logica di Calcolo Pura (async per Geocoding, usa tariffe caricate e nuove stagioni) -----
  Future<Map<String, dynamic>?> _performCalculationLogic(
      double mainDistanceKm, double? approachDistanceKm, double? returnDistanceKm, List<String> debugSteps
   ) async {
    if (_isLoadingConfigs || (_configsErrorMessage != null && !_configsErrorMessage!.contains("potrebbero non essere aggiornate")) || _tariffeFisseCaricate.isEmpty || _tariffeOrarieCaricate.isEmpty || _tariffeKmDispoCaricate.isEmpty || _tariffeKmTransferCaricate.isEmpty) {
        debugSteps.add("ERRORE: Tariffe non disponibili o caricamento fallito. Impossibile calcolare.");
        if(mounted) setState(() => _errorMessage = _configsErrorMessage ?? "Tariffe non caricate o vuote. Riprova più tardi.");
        return null;
    }

    debugSteps.add("--- Ricalcolo Interno Iniziato (${_cittaSelezionata.name}) ---");
    String partenzaAddrRaw = _partenzaController.text.trim(); String arrivoAddrRaw = _destinazioneController.text.trim();
    List<String> tappeAddrsRaw = _tappeController.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    String veicolo = _veicoloSelezionato ?? "BERLINA";

    String partenzaAddrVerified = await _getVerifiedAddress(partenzaAddrRaw); if (!mounted) return null;
    String arrivoAddrVerified = await _getVerifiedAddress(arrivoAddrRaw); if (!mounted) return null;
    List<String> tappeAddrsVerified = [];
    for (String tappaAddr in tappeAddrsRaw) { tappeAddrsVerified.add(await _getVerifiedAddress(tappaAddr)); if (!mounted) return null; }

    String zonaPartenzaCode = _getZoneCode(partenzaAddrVerified, _partenzaFuoriCentro);
    String zonaArrivoCode = _getZoneCode(arrivoAddrVerified, _destinazioneFuoriCentro);
    List<String> zoneTappeCodes = [];
    for(int i=0; i < tappeAddrsVerified.length; i++){ if (i < _tappeFuoriCentro.length) { zoneTappeCodes.add(_getZoneCode(tappeAddrsVerified[i], _tappeFuoriCentro[i])); } else { zoneTappeCodes.add(_getZoneCode(tappeAddrsVerified[i], false)); debugSteps.add("WARN: Flag 'FuoriCentro' mancante per tappa ${i+1}"); } }

    if (zonaPartenzaCode.startsWith("ERRORE") || zonaArrivoCode.startsWith("ERRORE") || zoneTappeCodes.any((z) => z.startsWith("ERRORE"))) {
         String geocodingErrorMsg = "Errore Geocoding: Impossibile determinare zona.";
         debugSteps.add("ERRORE: Geocoding fallito: $geocodingErrorMsg");
         throw Exception(geocodingErrorMsg.trim());
    }

    bool isConsideratoFuori = zonaPartenzaCode == "ALTRO" || zonaArrivoCode == "ALTRO" || zoneTappeCodes.contains("ALTRO");
    debugSteps.add("Zone Calcolate: P='$zonaPartenzaCode'(!FC:${!_partenzaFuoriCentro}), A='$zonaArrivoCode'(!FC:${!_destinazioneFuoriCentro}), T=$zoneTappeCodes, Fuori=$isConsideratoFuori");

    double? tariffaKmTransfer = _tariffeKmTransferCaricate[veicolo];
    double? tariffaKmDispo = _tariffeKmDispoCaricate[veicolo];
    if (tariffaKmTransfer == null || tariffaKmDispo == null) { debugSteps.add("ERRORE: Tariffe KM caricate non trovate per '$veicolo'"); return null; }

    double costoTragittoPrincipale = 0.0; double? tariffaFissaApplicata; double costoDispoCentro = 0.0; double costoDispoFuori = 0.0; double costoDispoOrariaTotale = 0.0; double costoKmDispo = 0.0; String dettaglioCostiBaseCalc = ""; double costoBaseServizio = 0.0; String tipoServizio = "N/D";
    String refAddress = (_cittaSelezionata == Citta.roma) ? ROMA_TERMINI_ADDRESS : MILANO_CADORNA_ADDRESS; String refCityName = (_cittaSelezionata == Citta.roma) ? "Roma" : "Milano"; double costoAvvicinamento = 0.0; String dettAvv = "N/A"; bool avvicinamentoEscluso = _noAvvicinamento; bool needsApproachCalc = zonaPartenzaCode == "ALTRO"; if (needsApproachCalc && !avvicinamentoEscluso) { if (approachDistanceKm != null && approachDistanceKm > 0) { costoAvvicinamento = approachDistanceKm * tariffaKmTransfer; dettAvv = "$approachDistanceKm km"; debugSteps.add("Avvicinamento da $refCityName: $dettAvv = ${costoAvvicinamento.toStringAsFixed(2)} €"); } else if (approachDistanceKm == null) { dettAvv = "ERRORE CALCOLO DIST."; debugSteps.add("Costo Avv: Errore Distanza API"); } else { dettAvv = "Distanza 0 km"; debugSteps.add("Costo Avv: Distanza 0"); } } else if (avvicinamentoEscluso) { dettAvv = "Escluso (Già sul posto)"; debugSteps.add("Costo Avv: Escluso"); }
    double costoRientro = 0.0; String dettRie = "N/A"; bool rientroEscluso = _noRientro; bool needsReturnCalc = zonaArrivoCode == "ALTRO"; if (needsReturnCalc && !rientroEscluso) { if (returnDistanceKm != null && returnDistanceKm > 0) { costoRientro = returnDistanceKm * tariffaKmTransfer; dettRie = "$returnDistanceKm km"; debugSteps.add("Rientro su $refCityName: $dettRie = ${costoRientro.toStringAsFixed(2)} €"); } else if (returnDistanceKm == null) { dettRie = "ERRORE CALCOLO DIST."; debugSteps.add("Costo Rie: Errore Distanza API"); } else { dettRie = "Distanza 0 km"; debugSteps.add("Costo Rie: Distanza 0"); } } else if (rientroEscluso) { dettRie = "Escluso (Non rientra)"; debugSteps.add("Costo Rie: Escluso"); }
    if (!_disposizioneAttiva) {
        tipoServizio = "Trasferimento"; debugSteps.add("Modalità: Trasferimento. Tento ricerca Tariffa Fissa..."); String keyFissa1 = "$veicolo|$zonaPartenzaCode|$zonaArrivoCode"; String keyFissa2 = "$veicolo|$zonaArrivoCode|$zonaPartenzaCode";
        tariffaFissaApplicata = _tariffeFisseCaricate[keyFissa1] ?? _tariffeFisseCaricate[keyFissa2];
        debugSteps.add("Risultato lookup TF: ${tariffaFissaApplicata?.toString() ?? 'null'}");
        if (tariffaFissaApplicata != null) { costoBaseServizio = tariffaFissaApplicata; tipoServizio += " Tariffa Fissa"; debugSteps.add("Applicata Tariffa Fissa: ${costoBaseServizio.toStringAsFixed(2)} €"); dettaglioCostiBaseCalc = "- Tariffa Fissa (${zonaPartenzaCode}-${zonaArrivoCode}): ${tariffaFissaApplicata.toStringAsFixed(2)} euro\n"; if (needsApproachCalc && !avvicinamentoEscluso) { tipoServizio += " + Avv."; costoBaseServizio += costoAvvicinamento; dettaglioCostiBaseCalc += "  + Avvicinamento ($dettAvv): ${costoAvvicinamento.toStringAsFixed(2)} euro\n";} else if (avvicinamentoEscluso) { dettaglioCostiBaseCalc += "  + Avvicinamento: $dettAvv\n";} if (needsReturnCalc && !rientroEscluso) { tipoServizio += " + Rie."; costoBaseServizio += costoRientro; dettaglioCostiBaseCalc += "  + Rientro ($dettRie): ${costoRientro.toStringAsFixed(2)} euro\n";} else if (rientroEscluso) { dettaglioCostiBaseCalc += "  + Rientro: $dettRie\n";} }
        else { tipoServizio += isConsideratoFuori ? " Fuori Zona (KM)" : " Standard (KM)"; debugSteps.add("Nessuna Tariffa Fissa trovata -> Calcolo KM"); if (mainDistanceKm <= 0) { debugSteps.add("ERRORE: Distanza principale non valida per calcolo KM"); return null; } costoTragittoPrincipale = mainDistanceKm * tariffaKmTransfer; debugSteps.add("Tragitto Principale (${mainDistanceKm.toStringAsFixed(1)} km * ${tariffaKmTransfer.toStringAsFixed(2)} €/km): ${costoTragittoPrincipale.toStringAsFixed(2)} €"); costoBaseServizio = costoTragittoPrincipale + costoAvvicinamento + costoRientro; dettaglioCostiBaseCalc = "- Tragitto (${mainDistanceKm.toStringAsFixed(1)} km): ${costoTragittoPrincipale.toStringAsFixed(2)} euro\n"; if (needsApproachCalc) { dettaglioCostiBaseCalc += "  + Avvicinamento ($dettAvv): ${costoAvvicinamento.toStringAsFixed(2)} euro\n";} else if (avvicinamentoEscluso) { dettaglioCostiBaseCalc += "  + Avvicinamento: $dettAvv\n";} if (needsReturnCalc) { dettaglioCostiBaseCalc += "  + Rientro ($dettRie): ${costoRientro.toStringAsFixed(2)} euro\n";} else if (rientroEscluso) { dettaglioCostiBaseCalc += "  + Rientro: $dettRie\n";} }
    } else {
         tipoServizio = isConsideratoFuori ? "Disposizione Fuori Zona" : "Disposizione Centro"; debugSteps.add("Modalità: Disposizione Oraria");
         costoDispoCentro = _calcolaCostoOrarioDispoZona(_oreExtraCentro, veicolo, "CENTRO", _blocco3hCentro, debugSteps);
         costoDispoFuori = _calcolaCostoOrarioDispoZona(_oreExtraFuori, veicolo, "FUORI", _blocco3hFuori, debugSteps);
         costoDispoOrariaTotale = costoDispoCentro + costoDispoFuori; debugSteps.add("Costo Orario Totale: ${costoDispoOrariaTotale.toStringAsFixed(2)} €"); dettaglioCostiBaseCalc += "- Disposizione Centro (Blocco:${_blocco3hCentro?'S':'N'}, Extra:${_oreExtraCentro}h): ${costoDispoCentro.toStringAsFixed(2)} euro\n"; dettaglioCostiBaseCalc += "- Disposizione Fuori (Blocco:${_blocco3hFuori?'S':'N'}, Extra:${_oreExtraFuori}h): ${costoDispoFuori.toStringAsFixed(2)} euro\n";
         if (isConsideratoFuori) { if (mainDistanceKm > 0) { costoKmDispo = mainDistanceKm * tariffaKmDispo; debugSteps.add("Costo KM Disposizione (${mainDistanceKm.toStringAsFixed(1)} km * ${tariffaKmDispo.toStringAsFixed(2)} €/km): ${costoKmDispo.toStringAsFixed(2)} €"); dettaglioCostiBaseCalc += "- KM Disposizione (${mainDistanceKm.toStringAsFixed(1)} km): ${costoKmDispo.toStringAsFixed(2)} euro\n";} else { debugSteps.add("Costo KM Disposizione: 0.00 € (Distanza 0)"); } }
         else { debugSteps.add("Costo KM Disposizione: 0.00 € (Interno Centro)"); }
         costoBaseServizio = costoDispoOrariaTotale + costoKmDispo + costoAvvicinamento + costoRientro;
         if (needsApproachCalc) { dettaglioCostiBaseCalc += "  + Avvicinamento ($dettAvv): ${costoAvvicinamento.toStringAsFixed(2)} euro\n";} else if (avvicinamentoEscluso) { dettaglioCostiBaseCalc += "  + Avvicinamento: $dettAvv\n";}
         if (needsReturnCalc) { dettaglioCostiBaseCalc += "  + Rientro ($dettRie): ${costoRientro.toStringAsFixed(2)} euro\n";} else if (rientroEscluso) { dettaglioCostiBaseCalc += "  + Rientro: $dettRie\n";}
    }
    dettaglioCostiBaseCalc = dettaglioCostiBaseCalc.trimRight();
    debugSteps.add("--- Fine Calcolo Base ---"); debugSteps.add("Costo Base Servizio Totale: ${costoBaseServizio.toStringAsFixed(2)} €");
    double costoVitto = _vittoAlloggioAttivo ? _costoVittoCaricato : 0.0;
    double costoExtraVal = 0.0; String notaExtra = "";
    if (_costiExtraAttivi) { costoExtraVal = double.tryParse(_importoExtraController.text.replaceAll(',', '.')) ?? 0.0; notaExtra = _noteExtraController.text.trim(); }
    double costoAccessoriTot = costoVitto + costoExtraVal;
    if (costoVitto > 0) debugSteps.add("Costo Vitto/Alloggio: +${costoVitto.toStringAsFixed(2)} €");
    if (costoExtraVal != 0 || (_costiExtraAttivi && notaExtra.isNotEmpty)) debugSteps.add("Costi Extra Manuali: +${costoExtraVal.toStringAsFixed(2)} € ('$notaExtra')");

    double supplNotturnoVal = _servizioNotturnoAttivo ? (costoBaseServizio * 0.10) : 0.0;
    double supplFestivoPerc = 0; double supplFestivoVal = 0.0;
    if (_supplementoFestivo50) { supplFestivoPerc = 50; supplFestivoVal = costoBaseServizio * 0.50; }
    else if (_supplementoFestivo30) { supplFestivoPerc = 30; supplFestivoVal = costoBaseServizio * 0.30; }

    // --- LOGICA SUPPLEMENTO STAGIONE AGGIORNATA ---
    double supplStagioneVal = 0.0;
    String nomeStagioneSuppl = "";
    double percStagioneSuppl = 0.0;
    if (_isAltaStagioneActive) {
        percStagioneSuppl = _altaStagionePercentCaricata;
        supplStagioneVal = costoBaseServizio * (percStagioneSuppl / 100.0);
        nomeStagioneSuppl = "Alta Stagione";
    } else if (_isAltissimaStagioneActive) {
        percStagioneSuppl = _altissimaStagionePercentCaricata;
        supplStagioneVal = costoBaseServizio * (percStagioneSuppl / 100.0);
        nomeStagioneSuppl = "Altissima Stagione";
    }
    // --- FINE LOGICA SUPPLEMENTO STAGIONE ---

    double costoSupplementiTot = supplNotturnoVal + supplFestivoVal + supplStagioneVal; // Usa supplStagioneVal

    if (supplNotturnoVal > 0) debugSteps.add("Suppl. Notturno (+10% su Base): +${supplNotturnoVal.toStringAsFixed(2)} €");
    if (supplFestivoVal > 0) debugSteps.add("Suppl. Festivo (+${supplFestivoPerc}% su Base): +${supplFestivoVal.toStringAsFixed(2)} €");
    if (supplStagioneVal > 0) {
      debugSteps.add("Suppl. $nomeStagioneSuppl (+${percStagioneSuppl.toStringAsFixed(0)}% su Base): +${supplStagioneVal.toStringAsFixed(2)} €");
    }

    double prezzoPrimaSconto = costoBaseServizio + costoAccessoriTot + costoSupplementiTot;
    debugSteps.add("Subtotale Prima di Sconto: ${prezzoPrimaSconto.toStringAsFixed(2)} €");
    double scontoPerc = double.tryParse(_scontoController.text.replaceAll(',', '.')) ?? 0.0; double importoSconto = 0.0;
    if (scontoPerc > 0 && scontoPerc <= 100) { importoSconto = prezzoPrimaSconto * (scontoPerc / 100.0); debugSteps.add("Sconto (${scontoPerc.toStringAsFixed(1)}%): -${importoSconto.toStringAsFixed(2)} €"); }
    else { debugSteps.add("Sconto: Nessuno"); scontoPerc = 0.0; }
    double imponibile = prezzoPrimaSconto - importoSconto;
    debugSteps.add("IMPORTO IMPONIBILE (Pre-IVA): ${imponibile.toStringAsFixed(2)} €");
    double importoIva = _applicaIva ? imponibile * (_ivaPercentCaricata / 100.0) : 0.0;
    double totaleFinale = imponibile + importoIva;

    // Stringa Dettaglio Finale per Dialogo
    bool costiExtraFlag = costoExtraVal != 0 || (_costiExtraAttivi && notaExtra.isNotEmpty);
    bool opzioniPresenti = costoAccessoriTot + costoSupplementiTot > 0; // costoSupplementiTot ora include supplStagioneVal
    String dettaglioCompletoDialogo = """
**Riepilogo Calcolo Preventivo**
Cliente: ${_clienteController.text.isNotEmpty ? _clienteController.text : "N/D"}
Partenza: $partenzaAddrRaw
${tappeAddrsRaw.isNotEmpty ? 'Tappe: ${tappeAddrsRaw.join(", ")}\n' : ''}Arrivo: $arrivoAddrRaw
Veicolo: $veicolo | Tipo Servizio: $tipoServizio
--------------------
**DETTAGLIO COSTO BASE**
$dettaglioCostiBaseCalc
  -> Totale Base Servizio: ${costoBaseServizio.toStringAsFixed(2)} euro
--------------------
**OPZIONI E SUPPLEMENTI**
${costoVitto > 0 ? '- Vitto/Alloggio: +${costoVitto.toStringAsFixed(2)} euro\n' : ''}${supplNotturnoVal > 0 ? '- Notturno (+10%): +${supplNotturnoVal.toStringAsFixed(2)} euro\n' : ''}${supplFestivoVal > 0 ? '- Festivo (+${supplFestivoPerc}%): +${supplFestivoVal.toStringAsFixed(2)} euro\n' : ''}${_isAltaStagioneActive && supplStagioneVal > 0 ? '- Alta Stagione (+${_altaStagionePercentCaricata.toStringAsFixed(0)}%): +${supplStagioneVal.toStringAsFixed(2)} euro\n' : ''}${_isAltissimaStagioneActive && supplStagioneVal > 0 ? '- Altissima Stagione (+${_altissimaStagionePercentCaricata.toStringAsFixed(0)}%): +${supplStagioneVal.toStringAsFixed(2)} euro\n' : ''}${costiExtraFlag ? '- Costi Extra ($notaExtra): +${costoExtraVal.toStringAsFixed(2)} euro\n' : ''}${!opzioniPresenti ? 'Nessuna\n' : ''}  -> Totale Opzioni/Suppl.: ${(costoAccessoriTot + costoSupplementiTot).toStringAsFixed(2)} euro
--------------------
**RIEPILOGO ECONOMICO**
${scontoPerc > 0 ? 'Subtotale Pre-Sconto: ${prezzoPrimaSconto.toStringAsFixed(2)} euro\n' : ''}${scontoPerc > 0 ? 'Sconto (${scontoPerc.toStringAsFixed(1)}%): -${importoSconto.toStringAsFixed(2)} euro\n' : 'Sconto: Nessuno\n'}Subtotale Imponibile: ${imponibile.toStringAsFixed(2)} euro
IVA (${_ivaPercentCaricata.toStringAsFixed(0)}%): ${_applicaIva ? '+${importoIva.toStringAsFixed(2)} euro' : 'Non Applicata'}
====================
**TOTALE FINALE (${_applicaIva ? 'IVA Incl.' : 'IVA Escl.'}): ${totaleFinale.toStringAsFixed(2)} euro**
====================
--- DEBUG STEPS ---
${debugSteps.join("\n")}
""";

    // Ritorna mappa strutturata
    return {
      'cliente': _clienteController.text.isNotEmpty ? _clienteController.text : "N/D", 'partenza': partenzaAddrRaw, 'arrivo': arrivoAddrRaw, 'tappe': tappeAddrsRaw,
      'veicolo': veicolo, 'tipoServizio': tipoServizio, 'isDisposizione': _disposizioneAttiva, 'tariffaFissaApplicata': tariffaFissaApplicata, 'kmPercorsi': mainDistanceKm, 'costoTragittoKM': costoTragittoPrincipale,
      'dettaglioAvvicinamento': dettAvv, 'costoAvvicinamento': costoAvvicinamento, 'avvicinamentoEscluso': avvicinamentoEscluso, 'dettaglioRientro': dettRie, 'costoRientro': costoRientro, 'rientroEscluso': rientroEscluso,
      'costoDispoCentro': costoDispoCentro, 'costoDispoFuori': costoDispoFuori, 'costoDispoOrariaTotale': costoDispoOrariaTotale, 'costoKmDispo': costoKmDispo,
      'costoBaseServizio': costoBaseServizio, 'dettaglioCostiBaseStr': dettaglioCostiBaseCalc,
      'costoVitto': costoVitto, 'costoExtraVal': costoExtraVal, 'notaExtra': notaExtra, 'costiExtraFlag': costiExtraFlag, 'costoAccessoriTot': costoAccessoriTot,
      'supplNotturnoVal': supplNotturnoVal, 'supplFestivoPerc': supplFestivoPerc, 'supplFestivoVal': supplFestivoVal,
      'isAltaStagioneActive': _isAltaStagioneActive, 'altaStagionePercent': _altaStagionePercentCaricata,
      'isAltissimaStagioneActive': _isAltissimaStagioneActive, 'altissimaStagionePercent': _altissimaStagionePercentCaricata,
      'supplStagioneVal': supplStagioneVal,
      'costoSupplementiTot': costoSupplementiTot,
      'subtotalePrimaSconto': prezzoPrimaSconto, 'scontoPerc': scontoPerc, 'importoSconto': importoSconto,
      'imponibile': imponibile, 'ivaApplicata': _applicaIva, 'importoIva': importoIva, 'totaleFinale': totaleFinale,
      'debugSteps': debugSteps, 'dettaglioCompletoDialogo': dettaglioCompletoDialogo
    };
  } // Fine _performCalculationLogic


  // Funzione per mostrare il Dialogo di Dettaglio (Usa stringa pre-formattata dalla mappa)
  void _showCalculationDialog(Map<String, dynamic> resultData) {
     String dialogDetails = resultData['dettaglioCompletoDialogo'] ?? "Errore: Dettaglio non disponibile.";
     showDialog( context: context, builder: (BuildContext dialogContext) { return AlertDialog( scrollable: true, title: Text('Dettaglio Calcolo'), content: SelectableText(dialogDetails), actions: <Widget>[ TextButton( child: Text('Chiudi'), onPressed: () => Navigator.of(dialogContext).pop(), ), ], ); }, );
   }

  // Funzione per generare e condividere TXT (AGGIORNATA per nuova stagione)
  Future<void> _generateAndShareTxt() async {
    if (_calculationResultData == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errore: Eseguire prima un calcolo valido.'), backgroundColor: Colors.orange)); return; }
    if (_errorMessage != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Risolvi prima l\'errore nel calcolo: $_errorMessage'), backgroundColor: Colors.red)); return; }
    final data = _calculationResultData!;
    final String cliente = data['cliente'] ?? 'N/D'; final String partenza = data['partenza'] ?? 'N/D'; final String arrivo = data['arrivo'] ?? 'N/D'; final List<String> tappe = List<String>.from(data['tappe'] ?? []); final String veicolo = data['veicolo'] ?? 'N/D'; final String tipoServizio = data['tipoServizio'] ?? 'N/D'; final String dettaglioCostiBaseStr = data['dettaglioCostiBaseStr'] ?? 'N/D'; final double costoBaseServizio = (data['costoBaseServizio'] as num?)?.toDouble() ?? 0.0; final double costoVitto = (data['costoVitto'] as num?)?.toDouble() ?? 0.0; final double costoExtraVal = (data['costoExtraVal'] as num?)?.toDouble() ?? 0.0; final String notaExtra = data['notaExtra'] ?? ''; final bool costiExtraFlag = data['costiExtraFlag'] ?? false; final double supplNotturnoVal = (data['supplNotturnoVal'] as num?)?.toDouble() ?? 0.0; final int supplFestivoPerc = (data['supplFestivoPerc'] as num?)?.toInt() ?? 0; final double supplFestivoVal = (data['supplFestivoVal'] as num?)?.toDouble() ?? 0.0;
    final bool isAltaStagioneActive = data['isAltaStagioneActive'] ?? false; final double altaStagionePercent = (data['altaStagionePercent'] as num?)?.toDouble() ?? 0.0;
    final bool isAltissimaStagioneActive = data['isAltissimaStagioneActive'] ?? false; final double altissimaStagionePercent = (data['altissimaStagionePercent'] as num?)?.toDouble() ?? 0.0;
    final double supplStagioneVal = (data['supplStagioneVal'] as num?)?.toDouble() ?? 0.0;
    final double subtotalePrimaSconto = (data['subtotalePrimaSconto'] as num?)?.toDouble() ?? 0.0; final double scontoPerc = (data['scontoPerc'] as num?)?.toDouble() ?? 0.0; final double importoSconto = (data['importoSconto'] as num?)?.toDouble() ?? 0.0; final double imponibile = (data['imponibile'] as num?)?.toDouble() ?? 0.0; final bool ivaApplicata = data['ivaApplicata'] as bool? ?? false; final double ivaPercentDaUsare = _ivaPercentCaricata; final double importoIva = (data['importoIva'] as num?)?.toDouble() ?? 0.0; final double totaleFinale = (data['totaleFinale'] as num?)?.toDouble() ?? 0.0; final double costoAccessoriTot = (data['costoAccessoriTot'] as num?)?.toDouble() ?? 0.0; final double costoSupplementiTot = (data['costoSupplementiTot'] as num?)?.toDouble() ?? 0.0;
    bool opzioniPresenti = costoVitto > 0 || supplNotturnoVal > 0 || supplFestivoVal > 0 || supplStagioneVal > 0 || costiExtraFlag;

    final buffer = StringBuffer();
    buffer.writeln("*****************************"); buffer.writeln("      DECUS ITALIA"); buffer.writeln(" Preventivo Servizio NCC"); buffer.writeln("*****************************"); buffer.writeln();
    buffer.writeln("Data Emissione: ${DateTime.now().toLocal().toString().substring(0, 16)}"); buffer.writeln("Città Riferimento: ${_cittaSelezionata.name}"); buffer.writeln();
    buffer.writeln("--- DETTAGLI VIAGGIO ---"); buffer.writeln("Cliente: $cliente"); buffer.writeln("Partenza: $partenza ${_partenzaFuoriCentro ? '(Fuori Centro)' : ''}"); if (tappe.isNotEmpty) { buffer.writeln('Tappe Intermedie:'); for(int i=0; i< tappe.length; i++){ buffer.writeln("- ${tappe[i]} ${ (i < _tappeFuoriCentro.length && _tappeFuoriCentro[i]) ? '(Fuori Centro)' : ''}"); } } buffer.writeln("Arrivo: $arrivo ${_destinazioneFuoriCentro ? '(Fuori Centro)' : ''}"); buffer.writeln("Veicolo Richiesto: $veicolo"); buffer.writeln("Tipo Servizio: $tipoServizio"); buffer.writeln("------------------------------"); buffer.writeln();
    buffer.writeln("--- DETTAGLIO COSTO BASE ---"); buffer.writeln(dettaglioCostiBaseStr); buffer.writeln("  -> Totale Base Servizio: ${costoBaseServizio.toStringAsFixed(2)} euro"); buffer.writeln("------------------------------"); buffer.writeln();
    buffer.writeln("--- OPZIONI E SUPPLEMENTI ---");
    if (!opzioniPresenti) { buffer.writeln("Nessuna");
    } else {
      if (costoVitto > 0) buffer.writeln("- Vitto/Alloggio: +${costoVitto.toStringAsFixed(2)} euro");
      if (supplNotturnoVal > 0) buffer.writeln("- Notturno (+10%): +${supplNotturnoVal.toStringAsFixed(2)} euro");
      if (supplFestivoVal > 0) buffer.writeln("- Festivo (+${supplFestivoPerc}%): +${supplFestivoVal.toStringAsFixed(2)} euro");
      if (isAltaStagioneActive && supplStagioneVal > 0) buffer.writeln("- Alta Stagione (+${altaStagionePercent.toStringAsFixed(0)}%): +${supplStagioneVal.toStringAsFixed(2)} euro");
      if (isAltissimaStagioneActive && supplStagioneVal > 0) buffer.writeln("- Altissima Stagione (+${altissimaStagionePercent.toStringAsFixed(0)}%): +${supplStagioneVal.toStringAsFixed(2)} euro");
      if (costiExtraFlag) buffer.writeln("- Costi Extra ${notaExtra.isNotEmpty ? '($notaExtra)' : ''}: +${costoExtraVal.toStringAsFixed(2)} euro");
      buffer.writeln("  -> Totale Opzioni/Suppl.: ${(costoAccessoriTot + costoSupplementiTot).toStringAsFixed(2)} euro"); // costoSupplementiTot include già supplStagioneVal
    }
    buffer.writeln("------------------------------"); buffer.writeln();
    buffer.writeln("--- RIEPILOGO ECONOMICO ---"); if (scontoPerc > 0) { buffer.writeln("Subtotale Pre-Sconto: ${subtotalePrimaSconto.toStringAsFixed(2)} euro"); buffer.writeln("Sconto (${scontoPerc.toStringAsFixed(1)}%): -${importoSconto.toStringAsFixed(2)} euro"); } else { buffer.writeln("Sconto: Nessuno"); } buffer.writeln("Subtotale Imponibile: ${imponibile.toStringAsFixed(2)} euro"); buffer.writeln("IVA (${ivaPercentDaUsare.toStringAsFixed(0)}%): ${ivaApplicata ? '+${importoIva.toStringAsFixed(2)} euro' : 'Non Applicata'}"); buffer.writeln("=============================="); buffer.writeln("**TOTALE FINALE (${ivaApplicata ? 'IVA Incl.' : 'IVA Escl.'}): ${totaleFinale.toStringAsFixed(2)} euro**"); buffer.writeln("=============================="); buffer.writeln(); buffer.writeln("Grazie per aver scelto i nostri servizi.");

    final String txtContent = buffer.toString(); final Uint8List txtBytes = utf8.encode(txtContent); final now = DateTime.now(); final String timestamp = "${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}${now.second.toString().padLeft(2,'0')}"; final String safeCliente = cliente.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim(); final String txtFilename = 'preventivo_${safeCliente.isNotEmpty ? safeCliente : "cliente"}_$timestamp.txt';
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try { String? savedPath = await FileSaver.instance.saveFile( name: txtFilename, bytes: txtBytes, ext: 'txt', mimeType: MimeType.text, ); if (mounted && savedPath != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preventivo salvato in: $savedPath'), backgroundColor: Colors.green)); print("File TXT salvato su desktop in: $savedPath"); } else if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvataggio annullato dall\'utente.'), backgroundColor: Colors.grey)); print("Salvataggio file TXT annullato dall'utente su desktop."); } }
      catch (e) { print("Errore durante FileSaver.saveFile: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore durante il salvataggio del file TXT: $e'), backgroundColor: Colors.red)); } }
    } else {
      try { await Share.shareXFiles( [XFile.fromData(txtBytes, name: txtFilename, mimeType: 'text/plain')], subject: 'Preventivo NCC Decus - ${cliente.isNotEmpty ? cliente : "NuovoCliente"}' ); print("Dialogo condivisione TXT avviato con nome file: $txtFilename"); }
      catch (e) { print("Errore durante Share.shareXFiles: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore durante condivisione TXT: $e'), backgroundColor: Colors.red)); } }
    }
  }

  // ----- METODO DISPOSE -----
  @override
  void dispose() {
    _clienteController.dispose(); _partenzaController.dispose(); _destinazioneController.dispose();
    _noteExtraController.dispose(); _importoExtraController.dispose(); _scontoController.dispose();
    for (var controller in _tappeController) { controller.dispose(); }
    super.dispose();
  }

// --- END PART 3 / START PART 4 ---
// Il metodo build (Parte 4) inizia qui sotto
// --- START PART 4 (Metodo Build Completo con Nuove Stagioni) ---
// File: lib/preventivo_screen.dart
// (Incolla questo DOPO la fine della PARTE 3)

  // ----- METODO BUILD -----
  @override
  Widget build(BuildContext context) {
    // Calcola totale da mostrare nell'UI
    double? totalToShow;
    if (_calculationResultData != null && _errorMessage == null) {
      double? imponibile = _calculationResultData!['imponibile'];
      if (imponibile != null) {
          // Usa IVA caricata se disponibile, altrimenti default
          double ivaDaUsare = _applicaIva ? (1 + (_ivaPercentCaricata / 100.0)) : 1.0;
          totalToShow = imponibile * ivaDaUsare;
       }
    }

    return Scaffold(
      appBar: AppBar( title: Text('Nuovo Preventivo'), backgroundColor: Theme.of(context).colorScheme.surface,),
      body: _isLoadingConfigs // Mostra caricamento se le tariffe non sono pronte
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Caricamento configurazioni...")],))
          : _configsErrorMessage != null && !_configsErrorMessage!.contains("potrebbero non essere aggiornate") // Mostra errore bloccante caricamento config
              ? Center(child: Padding(padding: EdgeInsets.all(20), child: Text("ERRORE CARICAMENTO CONFIG:\n$_configsErrorMessage\n\nL'app userà valori di default SE il caricamento da assets ha funzionato, altrimenti il calcolo potrebbe fallire.", style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center)))
              : SingleChildScrollView( // Mostra UI normale se tariffe caricate (o fallback ad asset)
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Messaggio di avviso se le tariffe non sono le ultime online ma da cache/asset
                      if (_configsErrorMessage != null && _configsErrorMessage!.contains("potrebbero non essere aggiornate"))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Container(
                            padding: EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Text(_configsErrorMessage!, style: TextStyle(color: Colors.orange.shade200)),
                          ),
                        ),

                      // --- Selettore Città ---
                      Text('Città di Riferimento', style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 8),
                      SegmentedButton<Citta>(
                        segments: const <ButtonSegment<Citta>>[
                          ButtonSegment<Citta>(value: Citta.roma, label: Text('Roma'), icon: Icon(Icons.location_city)),
                          ButtonSegment<Citta>(value: Citta.milano, label: Text('Milano'), icon: Icon(Icons.business)),
                        ],
                        selected: <Citta>{_cittaSelezionata},
                        onSelectionChanged: (Set<Citta> newSelection) {
                          setState(() { _cittaSelezionata = newSelection.first; _calculationResultData = null; _errorMessage = null; _calculatedKm = null; });
                        },
                        style: SegmentedButton.styleFrom( /* ... stili opzionali ... */ ),
                      ),
                      SizedBox(height: 24),

                      // --- Sezione Dati Principali (con Checkbox "Fuori Centro?") ---
                      Text('Dati Principali', style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 12),
                      TextField(controller: _clienteController, decoration: InputDecoration(labelText: 'Cliente')),
                      SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextField(controller: _partenzaController, decoration: InputDecoration(labelText: 'Indirizzo di Partenza'))),
                        SizedBox(width: 4),
                        Tooltip(message:"Spunta se l'indirizzo è FUORI dal centro", child: Row(mainAxisSize: MainAxisSize.min, children:[Text('FC?', style: TextStyle(fontSize: 12)), Checkbox(value: _partenzaFuoriCentro, visualDensity: VisualDensity.compact, onChanged: (v) => setState(()=>_partenzaFuoriCentro=v??false))])),
                        SizedBox(width: 4),
                        Tooltip(message:"Spunta se il veicolo è già sul posto", child: Row(mainAxisSize: MainAxisSize.min, children:[Text('Già P?', style: TextStyle(fontSize: 12)), Checkbox(value: _noAvvicinamento, visualDensity: VisualDensity.compact, onChanged: (v) => setState(()=>_noAvvicinamento=v??false))]))
                      ]),
                      SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextField(controller: _destinazioneController, decoration: InputDecoration(labelText: 'Indirizzo di Destinazione'))),
                        SizedBox(width: 4),
                        Tooltip(message:"Spunta se l'indirizzo è FUORI dal centro", child: Row(mainAxisSize: MainAxisSize.min, children:[Text('FC?', style: TextStyle(fontSize: 12)), Checkbox(value: _destinazioneFuoriCentro, visualDensity: VisualDensity.compact, onChanged: (v) => setState(()=>_destinazioneFuoriCentro=v??false))])),
                        SizedBox(width: 4),
                        Tooltip(message:"Spunta se il veicolo non rientra", child: Row(mainAxisSize: MainAxisSize.min, children:[Text('Non R?', style: TextStyle(fontSize: 12)), Checkbox(value: _noRientro, visualDensity: VisualDensity.compact, onChanged: (v) => setState(()=>_noRientro=v??false))]))
                      ]),
                      SizedBox(height: 24),

                      // --- Sezione Tappe Intermedie (con Checkbox "Fuori Centro?") ---
                      Text('Tappe Intermedie', style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 8),
                      if (_tappeController.isEmpty) Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Nessuna tappa aggiunta.', style: TextStyle(color: Colors.grey.shade400)), ),
                      ListView.builder(
                        shrinkWrap: true, physics: NeverScrollableScrollPhysics(), itemCount: _tappeController.length,
                        itemBuilder: (context, index) {
                          bool currentTappaFuoriCentro = (index < _tappeFuoriCentro.length) ? _tappeFuoriCentro[index] : false;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded( child: TextField( controller: _tappeController[index], decoration: InputDecoration(labelText: 'Tappa ${index + 1}'), ), ),
                                SizedBox(width: 8),
                                Tooltip(message:"Spunta se l'indirizzo è FUORI dal centro", child: Row(mainAxisSize: MainAxisSize.min, children:[Text('FC?', style: TextStyle(fontSize: 12)), Checkbox(value: currentTappaFuoriCentro, visualDensity: VisualDensity.compact, onChanged: (v) => setState(() { if(index < _tappeFuoriCentro.length) _tappeFuoriCentro[index]=v??false; } ))])),
                                IconButton( icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error), tooltip: 'Rimuovi Tappa', visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, onPressed: () => _rimuoviTappa(index), ),
                              ],
                            ),
                          );
                        },
                      ),
                      Align( alignment: Alignment.centerRight, child: TextButton.icon( icon: Icon(Icons.add_location_alt_outlined), label: Text('Aggiungi Tappa'), onPressed: _aggiungiTappa, ), ),
                      SizedBox(height: 24),

                      // --- Sezioni Veicolo, Disposizione, Costi Agg, Suppl/Sconto, Finalizzazione ---
                       Text('Veicolo', style: Theme.of(context).textTheme.titleLarge), SizedBox(height: 8), ListTile( title: Text(_veicoloSelezionato ?? 'Seleziona Veicolo...'), trailing: Icon(Icons.arrow_drop_down), onTap: _showVehicleDialog, ), SizedBox(height: 24),
                       Text('Disposizione e Opzioni', style: Theme.of(context).textTheme.titleLarge), SwitchListTile( title: Text('Servizio a Disposizione'), value: _disposizioneAttiva, onChanged: (bool v) => setState(() { _disposizioneAttiva = v; if (!v) {_oreExtraCentro=0;_oreExtraFuori=0;_blocco3hCentro=false;_blocco3hFuori=false;} }), contentPadding: EdgeInsets.zero, ), Visibility( visible: _disposizioneAttiva, child: AnimatedOpacity( duration: const Duration(milliseconds: 300), opacity: _disposizioneAttiva ? 1.0 : 0.0, child: Container( padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0, right: 8.0), margin: const EdgeInsets.only(top: 4.0, bottom: 8.0), decoration: BoxDecoration( border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)), borderRadius: BorderRadius.circular(8), color: Theme.of(context).colorScheme.primary.withOpacity(0.05) ), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ _buildHourSelector('Ore extra Centro:', _oreExtraCentro, (val) => setState(() => _oreExtraCentro = val)), SizedBox(height: 4), _buildHourSelector('Ore extra Fuori:', _oreExtraFuori, (val) => setState(() => _oreExtraFuori = val)), SizedBox(height: 8), CheckboxListTile( title: Text('Blocco 3h Centro'), value: _blocco3hCentro, onChanged: (bool? value) => setState(() => _blocco3hCentro = value ?? false), controlAffinity: ListTileControlAffinity.leading, dense: true, contentPadding: EdgeInsets.zero, ), CheckboxListTile( title: Text('Blocco 3h Fuori'), value: _blocco3hFuori, onChanged: (bool? value) => setState(() => _blocco3hFuori = value ?? false), controlAffinity: ListTileControlAffinity.leading, dense: true, contentPadding: EdgeInsets.zero, ), ], ), ), ), ), SizedBox(height: 16),
                       Text('Costi Aggiuntivi', style: Theme.of(context).textTheme.titleLarge), SwitchListTile( title: Text('Vitto Alloggio Autista (€${_costoVittoCaricato.toStringAsFixed(0)})'), value: _vittoAlloggioAttivo, onChanged: (bool v) => setState(() => _vittoAlloggioAttivo = v), contentPadding: EdgeInsets.zero, ), SwitchListTile( title: Text('Servizio Notturno (10%)'), value: _servizioNotturnoAttivo, onChanged: (bool v) => setState(() => _servizioNotturnoAttivo = v), contentPadding: EdgeInsets.zero, ), SwitchListTile( title: Text('Costi Extra Manuali'), value: _costiExtraAttivi, onChanged: (bool v) => setState(() { _costiExtraAttivi = v; if (!v) { _noteExtraController.clear(); _importoExtraController.clear();} }), contentPadding: EdgeInsets.zero, ), Visibility( visible: _costiExtraAttivi, child: AnimatedOpacity( duration: const Duration(milliseconds: 300), opacity: _costiExtraAttivi ? 1.0 : 0.0, child: Container( padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), margin: const EdgeInsets.only(top: 4.0, bottom: 8.0), decoration: BoxDecoration( border: Border.all(color: Colors.grey.shade700), borderRadius: BorderRadius.circular(8), ), child: Column( children: [ TextField( controller: _noteExtraController, decoration: InputDecoration(labelText: 'Note Costi Extra', border: UnderlineInputBorder(), isDense: true), maxLines: 2, ), SizedBox(height: 10), TextField( controller: _importoExtraController, decoration: InputDecoration( labelText: 'Importo Extra (€)', border: UnderlineInputBorder(), prefixText: '€ ', isDense: true ), keyboardType: TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))], ), ], ), ), ), ), SizedBox(height: 24),
                       Text('Supplementi e Sconto', style: Theme.of(context).textTheme.titleLarge), SwitchListTile( title: Text('Supplemento Festivo 50% (Natale...)'), value: _supplementoFestivo50, onChanged: (bool v) => setState(() { _supplementoFestivo50 = v; if (v) _supplementoFestivo30 = false; }), contentPadding: EdgeInsets.zero, ), SwitchListTile( title: Text('Supplemento Festivo 30% (Epifania...)'), value: _supplementoFestivo30, onChanged: (bool v) => setState(() { _supplementoFestivo30 = v; if (v) _supplementoFestivo50 = false; }), contentPadding: EdgeInsets.zero, ),
                       // --- NUOVI SWITCH STAGIONE ---
                       SwitchListTile(
                         title: Text('Alta Stagione (+${_altaStagionePercentCaricata.toStringAsFixed(0)}%)'),
                         value: _isAltaStagioneActive,
                         onChanged: (bool value) {
                           setState(() {
                             _isAltaStagioneActive = value;
                             if (value) { _isAltissimaStagioneActive = false; }
                           });
                         },
                         contentPadding: EdgeInsets.zero,
                       ),
                       SwitchListTile(
                         title: Text('Altissima Stagione (+${_altissimaStagionePercentCaricata.toStringAsFixed(0)}%)'),
                         value: _isAltissimaStagioneActive,
                         onChanged: (bool value) {
                           setState(() {
                             _isAltissimaStagioneActive = value;
                             if (value) { _isAltaStagioneActive = false; }
                           });
                         },
                         contentPadding: EdgeInsets.zero,
                       ),
                       // --- FINE NUOVI SWITCH ---
                       SizedBox(height: 16), Row( children: [ Text('SCONTO:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), SizedBox(width: 10), SizedBox( width: 80, child: TextField( controller: _scontoController, decoration: InputDecoration( border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), isDense: true, ), textAlign: TextAlign.right, keyboardType: TextInputType.numberWithOptions(decimal: true), inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.|,)?\d{0,1}')), ], ), ), SizedBox(width: 5), Text('%', style: TextStyle(fontSize: 16)), ], ), SizedBox(height: 24),
                       Text('Finalizzazione', style: Theme.of(context).textTheme.titleLarge), SwitchListTile( title: Text('Applica IVA (${_ivaPercentCaricata.toStringAsFixed(0)}%)'), value: _applicaIva, onChanged: (bool value) => setState(() => _applicaIva = value), contentPadding: EdgeInsets.zero, ),
                      SizedBox(height: 20),

                      // --- Sezione Visualizzazione Risultati Calcolo ---
                      Column( children: [ if (_isLoadingDistance) Padding( padding: const EdgeInsets.symmetric(vertical: 16.0), child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onBackground,)), SizedBox(width: 15), Text("Calcolo percorso...") ], ), ), if (_calculatedKm != null && !_isLoadingDistance) Container( width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 8.0), padding: EdgeInsets.all(12), decoration: BoxDecoration( color: Theme.of(context).colorScheme.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.5)) ), child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.route_outlined, color: Theme.of(context).colorScheme.secondary, size: 20), SizedBox(width: 10), Text( 'Distanza (Percorso Principale): ${_calculatedKm!.toStringAsFixed(1)} km', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center, ), ], ), ), if (_errorMessage != null && !_isLoadingDistance) Container( width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 8.0), padding: EdgeInsets.all(12), decoration: BoxDecoration( color: Theme.of(context).colorScheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.5)) ), child: Text( 'Errore: $_errorMessage', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold), textAlign: TextAlign.center, ), ), ], ), SizedBox(height: 10),

                      // --- Visualizzazione Totale Preventivo ---
                      if (_calculationResultData != null && !_isLoadingDistance && _errorMessage == null) Container( width: double.infinity, margin: const EdgeInsets.only(bottom: 20.0, top: 10.0), padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12), decoration: BoxDecoration( color: Colors.green.shade900.withOpacity(0.4), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade700) ), child: Center( child: Text( 'TOTALE PREVENTIVO: ${totalToShow?.toStringAsFixed(2) ?? 'Errore'} euro (${_applicaIva ? 'IVA Incl.' : 'IVA Escl.'})', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white), ), ), ),

                      // --- Pulsanti di Azione ---
                      Padding( padding: const EdgeInsets.only(top: 10.0, bottom: 20.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          ElevatedButton.icon(
                            icon: _isLoadingDistance ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Icon(Icons.calculate_outlined),
                            label: Text('CALCOLA'),
                            onPressed: (_isLoadingDistance || _isLoadingConfigs) ? null : () async {
                                FocusScope.of(context).unfocus();
                                setState(() { _isLoadingDistance = true; _errorMessage = null; _calculatedKm = null; _calculationResultData = null; });
                                List<String> cumulativeDebugSteps = ["--- Avvio Calcolo Pulsante (${_cittaSelezionata.name}) ---"];
                                double? finalMainDistanceKm; double? finalApproachDistanceKm; double? finalReturnDistanceKm; String? apiErrorMsg;
                                Map<String, dynamic>? calculationResult;
                                try {
                                    String originRaw = _partenzaController.text.trim();
                                    String destinationRaw = _destinazioneController.text.trim();
                                    List<String> waypointsRaw = _tappeController.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                                    final mainRouteResult = await _getRouteDetails(origin: originRaw, destination: destinationRaw, waypoints: waypointsRaw);
                                    if (!mainRouteResult['success']) { apiErrorMsg = mainRouteResult['message']; throw Exception(apiErrorMsg); }
                                    finalMainDistanceKm = mainRouteResult['distance_km'];
                                    if (finalMainDistanceKm == null) { throw Exception("Distanza principale non disponibile (null)."); }
                                    cumulativeDebugSteps.add("Distanza Principale OK: ${finalMainDistanceKm.toStringAsFixed(1)} km");
                                    if (!mounted) return;
                                    setState(() { _calculatedKm = finalMainDistanceKm; });
                                    String zonaP = _getZoneCode(originRaw, _partenzaFuoriCentro);
                                    String zonaA = _getZoneCode(destinationRaw, _destinazioneFuoriCentro);
                                    String refAddress = (_cittaSelezionata == Citta.roma) ? ROMA_TERMINI_ADDRESS : MILANO_CADORNA_ADDRESS;
                                    bool needsApproach = zonaP == "ALTRO" && !_noAvvicinamento;
                                    bool needsReturn = zonaA == "ALTRO" && !_noRientro;
                                    if (needsApproach) { final approachRouteResult = await _getRouteDetails(origin: refAddress, destination: originRaw); if (approachRouteResult['success']) { finalApproachDistanceKm = approachRouteResult['distance_km']; cumulativeDebugSteps.add("Avvicinamento OK: ${finalApproachDistanceKm?.toStringAsFixed(1) ?? 'N/A'} km"); } else { cumulativeDebugSteps.add("ERRORE Avvicinamento: ${approachRouteResult['message']}"); } } else { cumulativeDebugSteps.add("Avvicinamento non necessario/escluso."); }
                                    if (!mounted) return;
                                    if (needsReturn) { final returnRouteResult = await _getRouteDetails(origin: destinationRaw, destination: refAddress); if (returnRouteResult['success']) { finalReturnDistanceKm = returnRouteResult['distance_km']; cumulativeDebugSteps.add("Rientro OK: ${finalReturnDistanceKm?.toStringAsFixed(1) ?? 'N/A'} km"); } else { cumulativeDebugSteps.add("ERRORE Rientro: ${returnRouteResult['message']}"); } } else { cumulativeDebugSteps.add("Rientro non necessario/escluso."); }
                                    if (!mounted) return;
                                    calculationResult = await _performCalculationLogic( finalMainDistanceKm!, finalApproachDistanceKm, finalReturnDistanceKm, cumulativeDebugSteps );
                                    if (calculationResult != null) { if (!mounted) return; setState(() { _isLoadingDistance = false; _calculationResultData = calculationResult; _errorMessage = null; }); _showCalculationDialog(calculationResult); }
                                    else { if (!mounted) return; setState(() { _isLoadingDistance = false; _errorMessage = _errorMessage ?? cumulativeDebugSteps.lastWhere((s) => s.startsWith("ERRORE:"), orElse: () => "Errore sconosciuto."); _calculationResultData = null; }); }
                                } catch (e) { print("Errore onPressed CALCOLA: $e"); if (!mounted) return; setState(() { _isLoadingDistance = false; _errorMessage = apiErrorMsg ?? e.toString(); _calculationResultData = null; }); }
                            },
                           ),
                           ElevatedButton.icon(
                             icon: Icon(Icons.share), label: Text('Condividi TXT'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                             onPressed: (_isLoadingConfigs || _calculationResultData == null && _errorMessage == null) ? null : () { if (_errorMessage != null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Risolvi prima l\'errore nel calcolo!'), backgroundColor: Colors.red,)); return; } _generateAndShareTxt(); },
                           ),
                        ],
                      ), )
                    ],
                  ),
                ),
    );
  } // Fine build

} // --- END OF _PreventivoScreenState CLASS ---
// --- END OF FILE ---
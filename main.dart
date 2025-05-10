// File: lib/main.dart (Senza Firebase né dotenv)

import 'package:flutter/material.dart';
// RIMOSSO: import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'preventivo_screen.dart'; // Assicurati che questo file esista in lib/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // RIMOSSO: Caricamento dotenv
  // RIMOSSA: Inizializzazione Firebase

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryGold = Color(0xFFDAA520);
    const Color secondaryGold = Color(0xFFC0A060);
    const Color darkBackground = Color(0xFF303030);
    const Color darkSurface = Color(0xFF424242);
    const Color lightText = Color(0xFFEAEAEA);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App Preventivi Decus',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Segoe UI',
        colorScheme: const ColorScheme.dark(
          primary: primaryGold, secondary: secondaryGold, background: darkBackground,
          surface: darkSurface, onPrimary: Colors.black, onSecondary: Colors.black,
          onBackground: lightText, onSurface: lightText, error: Colors.redAccent, onError: Colors.white,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkSurface, foregroundColor: primaryGold, elevation: 0,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGold),
        ),
        inputDecorationTheme: InputDecorationTheme(
            filled: true, fillColor: darkSurface, hintStyle: TextStyle(color: lightText.withOpacity(0.6)),
            border: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide.none, ),
            enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.grey.shade700), ),
            focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: primaryGold, width: 1.5), ),
            labelStyle: TextStyle(color: lightText.withOpacity(0.8))),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGold, foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8.0), ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: primaryGold,
                textStyle: const TextStyle(fontWeight: FontWeight.bold))),
        listTileTheme: ListTileThemeData(
          iconColor: secondaryGold, tileColor: darkSurface,
          shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8.0), ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) { return primaryGold; }
            return darkSurface;
          }),
          checkColor: MaterialStateProperty.all(Colors.black),
          side: BorderSide(color: lightText.withOpacity(0.7)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) { return primaryGold; }
            return Colors.grey.shade400;
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) { return primaryGold.withOpacity(0.5); }
            return Colors.grey.shade700;
          }),
          trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: darkSurface,
          titleTextStyle: const TextStyle( color: primaryGold, fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: lightText),
          shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12.0), ),
        ),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( title: const Text('Gestione Preventivi Decus'), ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Image.asset(
                'assets/icon/app_icon.png',
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  print("Errore caricamento logo in HomePage: $error");
                  return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
                },
              ),
            ),
            const Text( 'Benvenuto!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500), ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_card),
              label: const Text('Crea Nuovo Preventivo'),
              onPressed: () {
                Navigator.push( context, MaterialPageRoute(builder: (context) => const PreventivoScreen()), );
              },
            ),
          ],
        ),
      ),
    );
  }
}
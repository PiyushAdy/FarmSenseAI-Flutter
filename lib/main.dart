import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:geolocator/geolocator.dart';

import 'ai_chat_feature.dart';
import 'firebase_options.dart';
import 'social_market.dart';
import 'app_config.dart';
import 'gemini_service.dart';
import 'plant_dashboard_screen.dart';
import 'diary_feature.dart';

// =================================================================================
// App Entry Point
// =================================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const FarmSenseApp());
}

// =================================================================================
// Main Application Widget
// =================================================================================
class FarmSenseApp extends StatelessWidget {
  const FarmSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmSense AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF3DDA84),
        fontFamily: 'Urbanist',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Urbanist',
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2),
          headlineSmall: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFE0E0E0), height: 1.5),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3DDA84),
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 36),
            textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Urbanist'),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          hintStyle: TextStyle(color: Colors.grey.shade600),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF3DDA84),
          foregroundColor: Colors.black,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// =================================================================================
// Data Models (No Changes)
// =================================================================================

class Plant {
  final String id;
  final String name;
  final String type;
  final String soilType;
  final String farmingPractices;
  final String resourcesAvailable;
  final double latitude;
  final double longitude;
  final String? healthStatus;

  Plant({
    required this.id,
    required this.name,
    required this.type,
    required this.soilType,
    required this.farmingPractices,
    required this.resourcesAvailable,
    required this.latitude,
    required this.longitude,
    this.healthStatus,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'soilType': soilType,
        'farmingPractices': farmingPractices,
        'resourcesAvailable': resourcesAvailable,
        'latitude': latitude,
        'longitude': longitude,
        'healthStatus': healthStatus,
      };

  factory Plant.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Plant(
      id: doc.id,
      name: data['name'] ?? 'Unknown Plant',
      type: data['type'] ?? 'N/A',
      soilType: data['soilType'] ?? 'N/A',
      farmingPractices: data['farmingPractices'] ?? 'N/A',
      resourcesAvailable: data['resourcesAvailable'] ?? 'N/A',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      healthStatus: data['healthStatus'],
    );
  }
}

class UserData {
  final String uid;
  final String username;
  final String email;
  UserData({required this.uid, required this.username, required this.email});
}

class RecommendedProduct {
  final String name;
  final String averagePrice;
  final String requiredQuantity;
  final List<String> relevantPlants;

  RecommendedProduct({
    required this.name,
    required this.averagePrice,
    required this.requiredQuantity,
    required this.relevantPlants,
  });

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) {
    return RecommendedProduct(
      name: json['product_name'] ?? 'N/A',
      averagePrice: json['average_price'] ?? 'N/A',
      requiredQuantity: json['required_quantity'] ?? 'N/A',
      relevantPlants: List<String>.from(json['relevant_plants'] ?? []),
    );
  }
}

class ProduceListing {
  final String? id;
  final String userId;
  final String username;
  final String userEmail;
  final String plantName;
  final String plantType;
  final String quantity;
  final String price;
  final String? phoneNumber;
  final Timestamp timestamp;

  ProduceListing({
    this.id,
    required this.userId,
    required this.username,
    required this.userEmail,
    required this.plantName,
    required this.plantType,
    required this.quantity,
    required this.price,
    this.phoneNumber,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userEmail': userEmail,
      'plantName': plantName,
      'plantType': plantType,
      'quantity': quantity,
      'price': price,
      'phoneNumber': phoneNumber,
      'timestamp': timestamp,
    };
  }

  factory ProduceListing.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ProduceListing(
      id: doc.id,
      userId: data['userId'],
      username: data['username'],
      userEmail: data['userEmail'],
      plantName: data['plantName'],
      plantType: data['plantType'],
      quantity: data['quantity'],
      price: data['price'],
      phoneNumber: data['phoneNumber'],
      timestamp: data['timestamp'],
    );
  }
}

class DiaryEntry {
  final String? id;
  final String title;
  final String content;
  final Timestamp timestamp;

  DiaryEntry({
    this.id,
    required this.title,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'timestamp': timestamp,
    };
  }

  factory DiaryEntry.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return DiaryEntry(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}

// =================================================================================
// Firebase & Other Services 
// =================================================================================

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? getCurrentUser() => _auth.currentUser;

  Future<UserData?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserData(
          uid: uid,
          username: doc.data()!['username'],
          email: doc.data()!['email']);
    }
    return null;
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signup(String email, String password, String username) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({'username': username, 'email': email});
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async => await _auth.signOut();
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  Stream<List<Plant>> getPlantsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('plants')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Plant.fromFirestore(doc)).toList());
  }

  Future<void> addPlant(String uid, Plant plant) async => await _firestore
      .collection('users')
      .doc(uid)
      .collection('plants')
      .add(plant.toMap());
  Future<void> updatePlant(String uid, Plant plant) async => await _firestore
      .collection('users')
      .doc(uid)
      .collection('plants')
      .doc(plant.id)
      .update(plant.toMap());
  Future<void> deletePlant(String uid, String plantId) async => await _firestore
      .collection('users')
      .doc(uid)
      .collection('plants')
      .doc(plantId)
      .delete();
  Future<DocumentSnapshot> getPlantDetails(String uid, String plantId) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('plants')
          .doc(plantId)
          .get();

  Future<void> saveSensorReading(
      String plantId, Map<String, dynamic> sensorData) async {
    final user = _authService.getCurrentUser();
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plantId)
        .collection('sensor_readings')
        .add({...sensorData, 'timestamp': FieldValue.serverTimestamp()});
  }

  Future<Map<String, dynamic>?> getLatestSensorReading(String plantId) async {
    final user = _authService.getCurrentUser();
    if (user == null) return null;
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plantId)
        .collection('sensor_readings')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null;
  }

  Future<void> addListing(ProduceListing listing) async =>
      await _firestore.collection('market_listings').add(listing.toMap());
  Future<void> updateListing(ProduceListing listing) async => await _firestore
      .collection('market_listings')
      .doc(listing.id)
      .update(listing.toMap());
  Future<void> deleteListing(String listingId) async =>
      await _firestore.collection('market_listings').doc(listingId).delete();

  Stream<List<ProduceListing>> getMyListingsStream(String uid) {
    return _firestore
        .collection('market_listings')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProduceListing.fromFirestore(doc))
            .toList());
  }

  Stream<List<ProduceListing>> getAllListingsStream() {
    return _firestore
        .collection('market_listings')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProduceListing.fromFirestore(doc))
            .toList());
  }

  // Diary Methods
  Stream<List<DiaryEntry>> getDiaryEntriesStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('diary_entries')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DiaryEntry.fromFirestore(doc))
            .toList());
  }

  Future<void> addDiaryEntry(String uid, DiaryEntry entry) async =>
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diary_entries')
          .add(entry.toMap());
  Future<void> updateDiaryEntry(String uid, DiaryEntry entry) async =>
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diary_entries')
          .doc(entry.id)
          .update(entry.toMap());
  Future<void> deleteDiaryEntry(String uid, String entryId) async =>
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diary_entries')
          .doc(entryId)
          .delete();
}

class WeatherService {
  final String _apiUrl = "https://api.openweathermap.org/data/2.5/weather";
  Future<Map<String, dynamic>> getCurrentWeather(double lat, double lon) async {
    if (ApiKeys.openWeatherApiKey.startsWith("YOUR_"))
      throw Exception("Add OpenWeatherMap API Key in `app_config.dart`.");
    final fullUrl =
        '$_apiUrl?lat=$lat&lon=$lon&appid=${ApiKeys.openWeatherApiKey}&units=metric';
    final response = await http.get(Uri.parse(fullUrl));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to load weather data.");
  }
}

class LocationService {
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled)
      return Future.error('Location services are disabled.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('Location permissions are denied');
    }
    if (permission == LocationPermission.deniedForever)
      return Future.error('Location permissions are permanently denied.');
    return await Geolocator.getCurrentPosition();
  }
}

// =================================================================================
// Screens
// =================================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      final user = AuthService().getCurrentUser();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (context) =>
                user != null ? const HomeScreen() : const GetStartedScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 100, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text('FarmSense AI',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 32)),
          ],
        ),
      ),
    );
  }
}

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(Icons.eco_outlined,
                  size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 20),
              Text('Get Started',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 10),
              Text('Your smart farming companion.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(flex: 3),
              ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('Login')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignUpScreen())),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: Theme.of(context).primaryColor),
                child: const Text('Signup'),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _performLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final error = await _authService.login(
        _emailController.text, _passwordController.text);
    setState(() => _isLoading = false);
    if (error == null && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false);
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).scaffoldBackgroundColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome\nBack',
                style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 40),
            TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: 'Email'),
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextField(
                controller: _passwordController,
                decoration: const InputDecoration(hintText: 'Password'),
                obscureText: true),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _performLogin, child: const Text('Login')),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _performSignUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = "Passwords do not match!");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final error = await _authService.signup(_emailController.text,
        _passwordController.text, _usernameController.text);
    setState(() => _isLoading = false);
    if (error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Signup successful! Please log in.")));
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false);
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).scaffoldBackgroundColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create\nAccount',
                style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 40),
            TextField(
                controller: _usernameController,
                decoration: const InputDecoration(hintText: 'Username')),
            const SizedBox(height: 16),
            TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: 'Email ID'),
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextField(
                controller: _passwordController,
                decoration: const InputDecoration(hintText: 'Password'),
                obscureText: true),
            const SizedBox(height: 16),
            TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(hintText: 'Confirm Password'),
                obscureText: true),
            if (_errorMessage != null)
              Padding(
                  padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _performSignUp, child: const Text('Sign Up')),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  User? _user;
  UserData? _userData;

  @override
  void initState() {
    super.initState();
    _user = _authService.getCurrentUser();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user != null) {
      _userData = await _authService.getUserData(_user!.uid);
      if (mounted) setState(() {});
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted)
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GetStartedScreen()),
          (route) => false);
  }

  Future<void> _deletePlant(String plantId) async {
    final bool? confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Plant?'),
        content: const Text(
            'Are you sure you want to delete this plant? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmDelete == true && _user != null) {
      try {
        await _firestoreService.deletePlant(_user!.uid, plantId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Plant deleted successfully'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error deleting plant: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddPlantScreen())),
        tooltip: 'Add Plant',
        icon: const Icon(Icons.add),
        label: const Text("Add Plant"),
      ),
      body: _user == null || _userData == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Plant>>(
              stream: _firestoreService.getPlantsStream(_user!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                final plants = snapshot.data ?? [];
                return CustomScrollView(
                  slivers: [
                    // lib/main.dart


                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 120.0,
                      
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding:
                            const EdgeInsets.only(left: 24, bottom: 16),
                        title: Text(
                          'Hello, ${_userData!.username} 👋🏻',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 26),
                        ),
                      ),
                      actions: [
                        IconButton(
                            icon: const Icon(Icons.logout_outlined),
                            onPressed: _logout,
                            tooltip: 'Logout')
                      ],
                    ),
// ...
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildStatCard(context,
                                count: plants.length.toString(),
                                label: 'Plants Monitored',
                                icon: Icons.grass,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(height: 30),
                            Text('Your Plants',
                                style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 10),
                            if (plants.isEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                                  child: Text(
                                      "You haven't added any plants yet. Tap the '+' button to get started!",
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade400))),
                          ],
                        ),
                      ),
                    ),
                    if (plants.isNotEmpty)
                      SliverToBoxAdapter(
                        // [FIXED] Adjusted height to prevent pixel overflow
                        child: SizedBox(
                          height: 265,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: plants.length,
                            itemBuilder: (context, index) => PlantCard(
                              plant: plants[index],
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlantDashboardScreen(plant: plants[index]))),
                              onEdit: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          AddPlantScreen(plant: plants[index]))),
                              onDelete: () => _deletePlant(plants[index].id),
                            ),
                          ),
                        ),
                      ),
                    _buildSectionHeader(context, 'AI-Powered Tools'),
                    SliverToBoxAdapter(
                        child: _buildAiFeaturesSection(context, plants)),
                    _buildSectionHeader(context, 'Farm Management'),
                    SliverToBoxAdapter(
                        child: _buildFarmManagementSection(
                            context, plants, _user!.uid, _userData!)),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }

  Widget _buildVerticalAiFeatureCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return Expanded(
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: color.withOpacity(0.5), width: 1),
        ),
        color: color.withOpacity(0.1),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

 
  Widget _buildAiFeaturesSection(BuildContext context, List<Plant> plants) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SizedBox(
        height: 180, // Give a fixed height to the row
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVerticalAiFeatureCard(
              context,
              icon: Icons.chat_bubble_outline,
              title: "AI Farm Advisor",
              subtitle: "Chat with your AI assistant",
              color: const Color(0xFF2575FC),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AiChatScreen(plants: plants))),
            ),
            const SizedBox(width: 16),
            _buildVerticalAiFeatureCard(
              context,
              icon: Icons.image_outlined,
              title: "Analyze Photo",
              subtitle: "Get insights from an image",
              color: const Color(0xFFF7971E),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      AiChatScreen(plants: plants, openWithImagePicker: true))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmManagementSection(
      BuildContext context, List<Plant> plants, String uid, UserData userData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          _buildNavigationCard(
            context,
            icon: Icons.book_outlined,
            title: "My Diary",
            subtitle: "Record your thoughts & experiences.",
            color: const Color(0xFFD32D41),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DiaryScreen(uid: uid))),
          ),
          const SizedBox(height: 16),
          _buildNavigationCard(
            context,
            icon: Icons.shopping_bag_outlined,
            title: "Supply Recommendations",
            subtitle: "AI-powered product suggestions.",
            color: const Color(0xFF4E54C8), // [FIXED] New color
            onTap: () {
              if (plants.isNotEmpty) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RecommendedProductsScreen(plants: plants)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text("Add at least one plant to get recommendations.")));
              }
            },
          ),
          const SizedBox(height: 16),
          _buildNavigationCard(
            context,
            icon: Icons.storefront_outlined,
            title: "My Farm Stand",
            subtitle: "Manage your produce listings.",
            color: const Color(0xFFFDBB2D),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MyListingsScreen(uid: uid, userData: userData))),
          ),
          const SizedBox(height: 16),
          _buildNavigationCard(
            context,
            icon: Icons.groups_outlined,
            title: "Community Market",
            subtitle: "Browse produce from other farmers.",
            color: const Color(0xFF22C1C3),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context,
      {required String count,
      required String label,
      required IconData icon,
      required Color color}) {
    return Card(
      color: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: color)),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: color.withOpacity(0.8))),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, size: 28, color: color)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.grey.shade400)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class AddPlantScreen extends StatefulWidget {
  final Plant? plant; // Make plant optional
  const AddPlantScreen({super.key, this.plant});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _soilTypeController = TextEditingController();
  final _farmingPracticesController = TextEditingController();
  final _resourcesController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _locationService = LocationService();
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;
  bool get _isEditMode => widget.plant != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameController.text = widget.plant!.name;
      _typeController.text = widget.plant!.type;
      _soilTypeController.text = widget.plant!.soilType;
      _farmingPracticesController.text = widget.plant!.farmingPractices;
      _resourcesController.text = widget.plant!.resourcesAvailable;
      _latController.text = widget.plant!.latitude.toString();
      _lonController.text = widget.plant!.longitude.toString();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final position = await _locationService.getCurrentPosition();
      _latController.text = position.latitude.toStringAsFixed(6);
      _lonController.text = position.longitude.toStringAsFixed(6);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not get location: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      final user = _authService.getCurrentUser();
      if (user == null) {
        setState(() => _isSubmitting = false);
        return;
      }

      final plantData = Plant(
        id: _isEditMode ? widget.plant!.id : '',
        name: _nameController.text,
        type: _typeController.text,
        soilType: _soilTypeController.text,
        farmingPractices: _farmingPracticesController.text,
        resourcesAvailable: _resourcesController.text,
        latitude: double.tryParse(_latController.text) ?? 0.0,
        longitude: double.tryParse(_lonController.text) ?? 0.0,
      );

      try {
        if (_isEditMode) {
          await _firestoreService.updatePlant(user.uid, plantData);
        } else {
          await _firestoreService.addPlant(user.uid, plantData);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditMode
                  ? 'Plant updated successfully!'
                  : 'Plant added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('An error occurred: $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _soilTypeController.dispose();
    _farmingPracticesController.dispose();
    _resourcesController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_isEditMode ? 'Edit Plant' : 'Add a New Plant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      hintText: 'Plant Name (e.g., Tomato)'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _typeController,
                  decoration: const InputDecoration(
                      hintText: 'Plant Type (e.g., Vegetable)'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _soilTypeController,
                  decoration:
                      const InputDecoration(hintText: 'Soil Type (e.g., Loamy)')),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _farmingPracticesController,
                  decoration: const InputDecoration(
                      hintText: 'Farming Practices (e.g., Organic)')),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _resourcesController,
                  decoration: const InputDecoration(
                      hintText: 'Resources Available (e.g., Drip Irrigation)')),
              const SizedBox(height: 24),
              Text("Field Location",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  controller: _latController,
                                  decoration: const InputDecoration(
                                      labelText: 'Latitude',
                                      border: UnderlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => (v == null ||
                                          v.isEmpty ||
                                          (double.tryParse(v) ?? 91) > 90 ||
                                          (double.tryParse(v) ?? -91) < -90)
                                      ? 'Invalid'
                                      : null)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: TextFormField(
                                  controller: _lonController,
                                  decoration: const InputDecoration(
                                      labelText: 'Longitude',
                                      border: UnderlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => (v == null ||
                                          v.isEmpty ||
                                          (double.tryParse(v) ?? 181) > 180 ||
                                          (double.tryParse(v) ?? -181) < -180)
                                      ? 'Invalid'
                                      : null)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _isFetchingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator())
                          : OutlinedButton.icon(
                              onPressed: _getCurrentLocation,
                              icon: const Icon(Icons.my_location),
                              label: const Text("Get Current Location"),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).primaryColor,
                                  side: BorderSide(
                                      color: Theme.of(context).primaryColor),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(30))),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitForm,
                      child: Text(_isEditMode ? 'Save Changes' : 'Add Plant'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecommendedProductsScreen extends StatefulWidget {
  final List<Plant> plants;
  const RecommendedProductsScreen({super.key, required this.plants});
  @override
  State<RecommendedProductsScreen> createState() =>
      _RecommendedProductsScreenState();
}

class _RecommendedProductsScreenState extends State<RecommendedProductsScreen>
    with SingleTickerProviderStateMixin {
  final GeminiService _geminiService = GeminiService();
  bool _isLoading = true;
  String? _error;
  List<RecommendedProduct> _products = [];
  late final AnimationController _animationController;
  final List<String> _loadingMessages = [
    "Analyzing your plant portfolio...",
    "Consulting agricultural databases...",
    "Identifying key needs...",
    "Generating product recommendations..."
  ];
  int _loadingMessageIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat();
    _startLoadingCycle();
    _fetchRecommendations();
  }

  void _startLoadingCycle() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _loadingMessageIndex =
          (_loadingMessageIndex + 1) % _loadingMessages.length);
    });
  }

  Future<void> _fetchRecommendations() async {
    try {
      final responseString =
          await _geminiService.getProductRecommendations(widget.plants);
      final cleanedString = responseString
          .replaceAll("```json", "")
          .replaceAll("```", "")
          .trim();
      final List<dynamic> decodedJson = jsonDecode(cleanedString);
      final products =
          decodedJson.map((json) => RecommendedProduct.fromJson(json)).toList();
      if (mounted)
        setState(() {
          _products = products;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error =
              "Failed to get recommendations. The AI might be busy or the response was not in the expected format. Please try again later.";
          _isLoading = false;
        });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recommended Products")),
      body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _isLoading
              ? _buildLoadingView()
              : _error != null
                  ? _buildErrorView()
                  : _buildResultsView()),
    );
  }

  Widget _buildLoadingView() => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RotationTransition(
                turns: _animationController,
                child: Icon(Icons.eco,
                    size: 100, color: Theme.of(context).primaryColor)),
            const SizedBox(height: 40),
            Text("Please wait",
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, 0.2), end: Offset.zero)
                            .animate(animation),
                        child: child)),
                child: Text(_loadingMessages[_loadingMessageIndex],
                    key: ValueKey<int>(_loadingMessageIndex),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.grey.shade400)))
          ]);
  Widget _buildErrorView() => Center(
          child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 60),
                    const SizedBox(height: 16),
                    Text("Something went wrong",
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge)
                  ])));
  Widget _buildResultsView() => _products.isEmpty
      ? const Center(
          child:
              Text("No specific product recommendations found at this time."))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _products.length,
          itemBuilder: (context, index) =>
              _ProductCard(product: _products[index]));
}

class _ProductCard extends StatelessWidget {
  final RecommendedProduct product;
  const _ProductCard({required this.product});
  IconData _getProductIcon(String name) {
    final lowerCaseName = name.toLowerCase();
    if (lowerCaseName.contains('fertilizer')) return Icons.local_florist;
    if (lowerCaseName.contains('pesticide') || lowerCaseName.contains('neem'))
      return Icons.bug_report;
    if (lowerCaseName.contains('seed')) return Icons.grain;
    if (lowerCaseName.contains('tool') || lowerCaseName.contains('sprayer'))
      return Icons.build;
    return Icons.shopping_basket;
  }

  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
          padding: const EdgeInsets.all(20.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(_getProductIcon(product.name),
                      color: Theme.of(context).primaryColor, size: 28)),
              const SizedBox(width: 16),
              Expanded(
                  child: Text(product.name,
                      style: Theme.of(context).textTheme.headlineSmall))
            ]),
            const Divider(height: 30, color: Colors.white12),
            _buildInfoRow(context, Icons.price_change_outlined, "Average Price",
                product.averagePrice),
            const SizedBox(height: 16),
            _buildInfoRow(
                context,
                Icons.production_quantity_limits_outlined,
                "Required Quantity",
                product.requiredQuantity),
            const SizedBox(height: 20),
            Text("Recommended for:",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: product.relevantPlants
                    .map((plantName) => Chip(
                        label: Text(plantName),
                        backgroundColor:
                            Theme.of(context).primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold),
                        side: BorderSide.none))
                    .toList())
          ])));
  Widget _buildInfoRow(
          BuildContext context, IconData icon, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.grey.shade400, size: 20),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.grey.shade400)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge)
        ]))
      ]);
}

// lib/main.dart

class PlantCard extends StatelessWidget {
  final Plant plant;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PlantCard({
    super.key,
    required this.plant,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Illustration/Icon Area
              Container(
                height: 124, // Reduced height to prevent overflow
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.3),
                      Theme.of(context).primaryColor.withOpacity(0.1)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(getPlantIcon(plant.type),
                    size: 56, color: Theme.of(context).primaryColor), // Adjusted icon size
              ),
              // Text Content Area
              Padding(
                // Reduced vertical padding
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plant.type,
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Action Buttons Area
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: onEdit,
                        tooltip: 'Edit',
                        color: Colors.grey.shade400),
                    IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        tooltip: 'Delete',
                        color: Colors.red.shade300),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData getPlantIcon(String type) {
  switch (type.toLowerCase()) {
    case 'vegetable':
      return Icons.local_florist;
    case 'fruit':
      return Icons.apple;
    case 'grain':
      return Icons.grain;
    default:
      return Icons.grass;
  }
}

extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
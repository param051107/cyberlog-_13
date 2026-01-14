import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await Hive.openBox('logs');
  runApp(const CyberLogApp());
}

/* ================= APP ================= */

class CyberLogApp extends StatelessWidget {
  const CyberLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0E0E12),
          cardColor: const Color(0xFF1A1A22),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

/* ================= STATE ================= */

class AppState extends ChangeNotifier {
  User? user;
  bool isOnline = true;

  AppState() {
    FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      sync();
      notifyListeners();
    });

    Connectivity().onConnectivityChanged.listen((r) {
      isOnline = r != ConnectivityResult.none;
      sync();
      notifyListeners();
    });
  }

  /* ---------- AUTH ---------- */

  Future<void> login(String email, String pass) async {
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: pass);
  }

  Future<void> register(String email, String pass) async {
    await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: pass);
  }

  void logout() {
    FirebaseAuth.instance.signOut();
  }

  /* ---------- LOGS ---------- */

  Future<void> addLog(String text) async {
    final box = Hive.box('logs');
    final logText =
        text.trim().isEmpty ? 'Log ${box.length + 1}' : text.trim();

    box.add({
      'text': logText,
      'synced': false,
      'cloudId': null,
    });

    sync();
    notifyListeners();
  }

  Future<void> deleteLog(int index) async {
    final box = Hive.box('logs');
    final log = box.getAt(index);

    if (log['cloudId'] != null && user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('logs')
          .doc(log['cloudId'])
          .delete()
          .catchError((_) {});
    }

    await box.deleteAt(index);
    notifyListeners();
  }

  Future<void> sync() async {
    if (!isOnline || user == null) return;

    final box = Hive.box('logs');
    final cloud = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('logs');

    for (int i = 0; i < box.length; i++) {
      final log = box.getAt(i);
      if (log['synced'] == false) {
        final doc = await cloud.add({
          'text': log['text'],
          'time': FieldValue.serverTimestamp(),
        });

        box.putAt(i, {
          'text': log['text'],
          'synced': true,
          'cloudId': doc.id,
        });
      }
    }
  }
}

/* ================= SPLASH ================= */

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });

    return const Scaffold(
      body: Center(
        child: Text(
          'CyberLog',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/* ================= LOGIN ================= */

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final email = TextEditingController();
    final pass = TextEditingController();

    if (app.user != null) return const LogsScreen();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login or Skip'),
        centerTitle: true,
      ),
      body: Center(
        child: Card(
          elevation: 10,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CyberLog Access',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),

                const SizedBox(height: 24),

               SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () =>
        app.login(email.text.trim(), pass.text.trim()),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent, // dark theme friendly
      foregroundColor: Colors.white,
      elevation: 0,
      side: const BorderSide(
        color: Colors.purpleAccent, // 🔥 border color
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    child: const Text(
      'Login',
      style: TextStyle(fontSize: 16),
    ),
  ),
),

                const SizedBox(height: 8),

                SizedBox(
  width: double.infinity,
  child: OutlinedButton(
    onPressed: () =>
        app.register(email.text.trim(), pass.text.trim()),
    style: OutlinedButton.styleFrom(
      side: const BorderSide(
        color: Colors.purpleAccent, // 🔥 border color
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    child: const Text(
      'Register',
      style: TextStyle(fontSize: 16),
    ),
  ),
),


                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LogsScreen()),
                    );
                  },
                  child: const Text('Skip (Local Mode)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ================= LOGS ================= */
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final box = Hive.box('logs');
    final input = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          },
        ),
        title: const Text('Cyber Logs'),
        actions: [
          if (app.user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Logout'),
                    content:
                        const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          app.logout();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (_) => false,
                          );
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('New Log'),
              content: TextField(
                controller: input,
                decoration:
                    const InputDecoration(hintText: 'Enter log'),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    app.addLog(input.text);
                    input.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('SAVE'),
                ),
              ],
            ),
          );
        },
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: box.length,
        itemBuilder: (_, i) {
          final log = box.getAt(i);

          return Card(
            child: ListTile(
              title: Text(log['text']),
              subtitle: Text(
                log['synced'] ? 'Synced to cloud' : 'Local only',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    log['synced']
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                    color: log['synced']
                        ? Colors.greenAccent
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Log'),
                          content: const Text(
                              'Are you sure you want to delete this log?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                app.deleteLog(i);
                                Navigator.pop(context);
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

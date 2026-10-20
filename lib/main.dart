import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

const green = Color(0xFF2E7D32);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const LendlyApp());
}

class LendlyApp extends StatelessWidget {
  const LendlyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lendly',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: const Color(0xFFF7F8F5),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, state) {
      if (state.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return state.data == null ? const LoginScreen() : const GroupScreen();
    },
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), email = TextEditingController(), password = TextEditingController();
  bool signup = false, hidePassword = true, busy = false;
  String? error;

  @override
  void dispose() { name.dispose(); email.dispose(); password.dispose(); super.dispose(); }

  String authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return 'An account already uses this email.';
      case 'invalid-email': return 'Enter a valid email address.';
      case 'weak-password': return 'Use at least 6 characters for your password.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found': return 'Email or password is incorrect.';
      default: return 'Sign-in failed: ${e.code}';
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() { busy = true; error = null; });
    try {
      final auth = FirebaseAuth.instance;
      if (signup) {
        final result = await auth.createUserWithEmailAndPassword(email: email.text.trim(), password: password.text);
        await result.user?.updateDisplayName(name.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
          'uid': result.user!.uid, 'displayName': name.text.trim(),
          'email': email.text.trim(), 'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await auth.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = authError(e));
    } catch (_) {
      setState(() => error = 'Something went wrong. Check Firebase setup and internet.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> googleLogin() async {
    setState(() { busy = true; error = null; });
    try {
      final google = await GoogleSignIn().signIn();
      if (google == null) return;
      final token = await google.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: token.accessToken, idToken: token.idToken);
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid, 'displayName': user.displayName ?? 'Neighbor',
        'email': user.email, 'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      setState(() => error = 'Google sign-in needs Firebase OAuth setup. See README.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> resetPassword() async {
    if (!email.text.trim().contains('@')) {
      setState(() => error = 'Enter your email address first.'); return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('If the account exists, a reset email has been sent.')));
    } on FirebaseAuthException catch (e) { setState(() => error = authError(e)); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Form(
        key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 76, width: 76, alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFE4F2E2), borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.handshake_rounded, color: green, size: 42)),
          const SizedBox(height: 22),
          const Text('Lendly', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(signup ? 'Join your neighborhood sharing circle.' : 'Borrow more. Buy less. Get to know your neighbors.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
          const SizedBox(height: 26),
          if (signup) ...[
            TextFormField(controller: name, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name.' : null),
            const SizedBox(height: 14),
          ],
          TextFormField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)),
            validator: (v) => (v == null || !v.trim().contains('@')) ? 'Enter a valid email.' : null),
          const SizedBox(height: 14),
          TextFormField(controller: password, obscureText: hidePassword,
            decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(onPressed: () => setState(() => hidePassword = !hidePassword),
                icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
            validator: (v) => (v == null || v.length < 6) ? 'Use at least 6 characters.' : null),
          if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red))],
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(signup ? 'Create account' : 'Log in')),
          if (!signup) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: resetPassword, child: const Text('Forgot password?'))),
          OutlinedButton.icon(onPressed: busy ? null : googleLogin, icon: const Icon(Icons.g_mobiledata, size: 30),
            label: const Text('Continue with Google'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54))),
          const SizedBox(height: 10),
          TextButton(onPressed: busy ? null : () => setState(() { signup = !signup; error = null; }),
            child: Text(signup ? 'Already have an account? Log in' : 'New to Lendly? Create an account')),
          const SizedBox(height: 10),
          Text('Private sharing for people who live, learn, or spend time nearby.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ]),
      )),
    ))),
  );
}

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});
  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final code = TextEditingController(), groupName = TextEditingController();
  String type = 'Building';
  bool busy = false;
  String? error;

  @override
  void dispose() { code.dispose(); groupName.dispose(); super.dispose(); }

  Future<void> join() async {
    final invite = code.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(invite)) {
      setState(() => error = 'Enter the 6-character invite code.'); return;
    }
    setState(() { busy = true; error = null; });
    try {
      final db = FirebaseFirestore.instance;
      // Prototype lookup: replace with a callable Cloud Function before launch.
      final result = await db.collection('groups').where('inviteCode', isEqualTo: invite).limit(1).get();
      if (result.docs.isEmpty) { setState(() => error = 'Invalid invite code. Ask the group admin to check it.'); return; }
      final group = result.docs.first;
      final user = FirebaseAuth.instance.currentUser!;
      final member = group.reference.collection('members').doc(user.uid);
      if ((await member.get()).exists) { setState(() => error = 'You are already a member of this group.'); return; }
      await member.set({'uid': user.uid, 'role': 'member', 'joinedAt': FieldValue.serverTimestamp()});
      await db.collection('users').doc(user.uid).set({'groups': FieldValue.arrayUnion([group.id])}, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined ${group.data()['name'] ?? 'the group'}')));
    } on FirebaseException catch (e) {
      setState(() => error = 'Could not join group (${e.code}). Review Firebase rules and README.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> create() async {
    if (groupName.text.trim().length < 3) { setState(() => error = 'Group name must be at least 3 characters.'); return; }
    setState(() { busy = true; error = null; });
    try {
      final db = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser!;
      final random = DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase();
      final invite = random.substring(random.length - 6);
      final ref = db.collection('groups').doc();
      await ref.set({'name': groupName.text.trim(), 'type': type, 'description': '',
        'inviteCode': invite, 'createdBy': user.uid, 'createdAt': FieldValue.serverTimestamp()});
      await ref.collection('members').doc(user.uid).set({'uid': user.uid, 'role': 'admin', 'joinedAt': FieldValue.serverTimestamp()});
      await db.collection('users').doc(user.uid).set({'groups': FieldValue.arrayUnion([ref.id])}, SetOptions(merge: true));
      if (mounted) showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: const Text('Your group is ready!'),
        content: SelectableText('Invite code: $invite\n\nShare this code only with people you want in your private group.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]));
    } on FirebaseException catch (e) {
      setState(() => error = 'Could not create group (${e.code}). Review README setup notes.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your sharing circle', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout), tooltip: 'Log out')]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFFE4F2E2), borderRadius: BorderRadius.circular(24)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.groups_rounded, color: green, size: 36), SizedBox(height: 12),
          Text('Sharing starts nearby.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          SizedBox(height: 8), Text('Create a private group or join one with an invite code from someone you know.'),
        ])),
      const SizedBox(height: 18),
      Card(color: Colors.white, elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Join a group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), const Text('Have a 6-character invite code?'), const SizedBox(height: 12),
        TextField(controller: code, maxLength: 6, textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Invite code', prefixIcon: Icon(Icons.key_outlined), counterText: '')),
        const SizedBox(height: 10), FilledButton(onPressed: busy ? null : join, child: const Text('Join with code')),
      ]))),
      const SizedBox(height: 14),
      Card(color: Colors.white, elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Create a group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), const Text('For your building, street, school, or club.'),
        const SizedBox(height: 12), TextField(controller: groupName, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Group name', prefixIcon: Icon(Icons.home_work_outlined))),
        const SizedBox(height: 12), DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Group type'),
          items: const ['Building', 'Street', 'School', 'Club', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) { if (v != null) setState(() => type = v); }),
        if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))],
        const SizedBox(height: 12), FilledButton.tonalIcon(onPressed: busy ? null : create, icon: const Icon(Icons.add_home_work_outlined), label: const Text('Create a group')),
      ]))),
      if (busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
      const SizedBox(height: 12),
      Text('Signed in as ${FirebaseAuth.instance.currentUser?.email ?? 'your account'}',
        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    ]),
  );
}

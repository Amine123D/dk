import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
      if (state.data == null) return const LoginScreen();
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').doc(state.data!.uid).get(),
        builder: (context, profile) {
          if (profile.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final ids = (profile.data?.data()?['groups'] as List<dynamic>?) ?? const [];
          if (ids.isEmpty) return const GroupScreen();
          return const HomeScreen();
        },
      );
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
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen(initialGroupId: group.id, initialGroupName: (group.data()['name'] ?? 'Your group').toString())),
          (route) => false,
        );
      }
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
      if (mounted) {
        await showDialog<void>(context: context, builder: (context) => AlertDialog(
          title: const Text('Your group is ready!'),
          content: SelectableText('Invite code: $invite\\n\\nShare this code only with people you want in your private group.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continue'))]));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen(initialGroupId: ref.id, initialGroupName: groupName.text.trim())),
            (route) => false,
          );
        }
      }
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


class HomeScreen extends StatefulWidget {
  final String? initialGroupId;
  final String? initialGroupName;
  const HomeScreen({super.key, this.initialGroupId, this.initialGroupName});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String? activeGroupId;
  String activeGroupName = 'Your sharing circle';
  String category = 'All';
  String sortBy = 'Newest';
  bool availableOnly = false;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    activeGroupId = widget.initialGroupId;
    activeGroupName = widget.initialGroupName ?? activeGroupName;
    if (activeGroupId == null) _loadDefaultGroup();
  }

  Future<void> _loadDefaultGroup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final ids = (profile.data()?['groups'] as List<dynamic>?) ?? const [];
      if (ids.isEmpty) return;
      final group = await FirebaseFirestore.instance.collection('groups').doc(ids.first.toString()).get();
      if (!mounted || !group.exists) return;
      setState(() {
        activeGroupId = group.id;
        activeGroupName = (group.data()?['name'] ?? 'Your sharing circle').toString();
      });
    } catch (_) {
      // Keep the shell usable; the feed shows a helpful empty state if no group loads.
    }
  }

  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> chooseGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final ids = (profile.data()?['groups'] as List<dynamic>?) ?? const [];
      final groups = <Map<String, String>>[];
      for (final id in ids) {
        final snap = await FirebaseFirestore.instance.collection('groups').doc(id.toString()).get();
        if (snap.exists) groups.add({'id': snap.id, 'name': (snap.data()?['name'] ?? 'Group').toString()});
      }
      if (!mounted) return;
      if (groups.isEmpty) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const GroupScreen()), (route) => false);
        return;
      }
      await showModalBottomSheet<void>(
        context: context, showDragHandle: true,
        builder: (sheetContext) => SafeArea(child: ListView(
          shrinkWrap: true, padding: const EdgeInsets.all(16),
          children: [
            const Text('Switch sharing group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final group in groups)
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE4F2E2), child: Icon(Icons.groups_rounded, color: green)),
                title: Text(group['name']!),
                trailing: group['id'] == activeGroupId ? const Icon(Icons.check_circle, color: green) : null,
                onTap: () {
                  setState(() { activeGroupId = group['id']; activeGroupName = group['name']!; });
                  Navigator.pop(sheetContext);
                },
              ),
            const Divider(),
            ListTile(leading: const Icon(Icons.add), title: const Text('Join or create another group'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupScreen()));
              }),
          ],
        )),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load your groups. Check your connection and Firebase rules.')));
    }
  }

  Widget emptyTab(IconData icon, String title, String message) => Center(
    child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFFE4F2E2), shape: BoxShape.circle),
        child: Icon(icon, color: green, size: 42)),
      const SizedBox(height: 18),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
    ])),
  );

  Widget buildHomeFeed() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: TextField(
      controller: search, decoration: InputDecoration(
        hintText: 'Search things to borrow', prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(onPressed: () => setState(() => search.clear()), icon: const Icon(Icons.close))),
      onChanged: (_) => setState(() {}),
    )),
    SizedBox(height: 54, child: ListView(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      children: ['All', 'Tools', 'Garden', 'Kitchen', 'Camping', 'Sports', 'Electronics', 'Party', 'Kids', 'Books', 'Other']
        .map((value) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(label: Text(value), selected: category == value, onSelected: (_) => setState(() => category = value))).toList(),
    )),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [
      FilterChip(label: const Text('Available only'), avatar: const Icon(Icons.check_circle_outline, size: 18),
        selected: availableOnly, onSelected: (value) => setState(() => availableOnly = value)),
      const Spacer(),
      PopupMenuButton<String>(
        tooltip: 'Sort items', icon: const Icon(Icons.sort),
        onSelected: (value) => setState(() => sortBy = value),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'Newest', child: Text('Newest')),
          PopupMenuItem(value: 'Title A–Z', child: Text('Title A–Z')),
        ],
      ),
    ])),
    Expanded(child: activeGroupId == null
      ? emptyTab(Icons.groups_outlined, 'Choose a group', 'Select a private group to see items shared by its members.')
      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('items').where('groupId', isEqualTo: activeGroupId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return emptyTab(Icons.cloud_off_outlined, 'Could not load items', 'Check your connection and Firestore rules, then try again.');
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final query = search.text.trim().toLowerCase();
            final docs = (snapshot.data?.docs ?? []).where((doc) {
              final data = doc.data();
              final matchesText = query.isEmpty ||
                (data['title'] ?? '').toString().toLowerCase().contains(query) ||
                (data['description'] ?? '').toString().toLowerCase().contains(query);
              final matchesCategory = category == 'All' || data['category'] == category;
              final matchesAvailability = !availableOnly || data['available'] == true;
              return matchesText && matchesCategory && matchesAvailability;
            }).toList();
            docs.sort((a, b) {
              if (sortBy == 'Title A–Z') return (a.data()['title'] ?? '').toString().compareTo((b.data()['title'] ?? '').toString());
              final at = a.data()['createdAt'];
              final bt = b.data()['createdAt'];
              if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
              return 0;
            });
            if (docs.isEmpty) return emptyTab(Icons.inventory_2_outlined, 'Nothing shared yet', query.isEmpty
              ? 'Be the first to add an item to this group.'
              : 'No items match your search or filters.');
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final images = (data['imageUrls'] as List<dynamic>?) ?? const [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12), clipBehavior: Clip.antiAlias,
                  color: Colors.white, elevation: 0,
                  child: InkWell(onTap: () => showModalBottomSheet<void>(
                    context: context, isScrollControlled: true, showDragHandle: true,
                    builder: (ctx) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text((data['title'] ?? 'Item').toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('${data['category'] ?? 'Other'} · ${data['condition'] ?? 'Condition not specified'}', style: TextStyle(color: Colors.grey.shade700)),
                        if (images.isNotEmpty) ...[const SizedBox(height: 14), SizedBox(height: 190, child: ListView(scrollDirection: Axis.horizontal, children: images.map((url) => Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(url.toString(), width: 220, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 220, child: Icon(Icons.broken_image_outlined))))).toList()))],
                        const SizedBox(height: 14),
                        Text((data['description'] ?? 'No description added.').toString()),
                        const SizedBox(height: 12),
                        Text('Loan period: up to ${data['maxLoanDays'] ?? 7} days'),
                        if ((data['rules'] ?? '').toString().trim().isNotEmpty) ...[const SizedBox(height: 8), Text('Owner notes: ${data['rules']}')],
                        const SizedBox(height: 16),
                        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                      ],
                    ))),
                  ), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 116, height: 132, child: images.isNotEmpty
                      ? Image.network(images.first.toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFE4F2E2), child: Icon(Icons.inventory_2_outlined, size: 36, color: green)))
                      : const ColoredBox(color: Color(0xFFE4F2E2), child: Icon(Icons.inventory_2_outlined, size: 36, color: green))),
                    Expanded(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text((data['title'] ?? 'Untitled item').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), const SizedBox(width: 6), if (data['available'] == true) const Icon(Icons.check_circle, color: green, size: 18)]),
                      const SizedBox(height: 5),
                      Text((data['category'] ?? 'Other').toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text((data['description'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      Text('Up to ${data['maxLoanDays'] ?? 7} days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]))),
                  ])),
                );
              },
            );
          },
        )),
  ]);

  @override
  Widget build(BuildContext context) {
    final titles = ['Home', 'My Items', 'Requests', 'Profile'];
    final body = switch (tab) {
      0 => buildHomeFeed(),
      1 => emptyTab(Icons.inventory_2_outlined, 'My items', 'Your listings and borrowed items will appear here in a later milestone.'),
      2 => emptyTab(Icons.inbox_outlined, 'Requests', 'Borrowing requests and pickup details will appear here in a later milestone.'),
      _ => emptyTab(Icons.person_outline, 'Your profile', 'Profile, groups, favorites, and trust score will be added in a later milestone.'),
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: InkWell(borderRadius: BorderRadius.circular(12), onTap: chooseGroup,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const CircleAvatar(radius: 18, backgroundColor: Color(0xFFE4F2E2), child: Icon(Icons.groups_rounded, color: green, size: 21)),
            const SizedBox(width: 10),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(activeGroupName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Text('Private sharing group', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
            const Icon(Icons.keyboard_arrow_down),
          ]),
        ),
        actions: [
          IconButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications will be enabled in a later milestone.'))),
            icon: const Icon(Icons.notifications_none_rounded), tooltip: 'Notifications'),
          IconButton(onPressed: () async { await FirebaseAuth.instance.signOut(); },
            icon: const Icon(Icons.logout_rounded), tooltip: 'Log out'),
        ],
      ),
      body: SafeArea(child: Column(children: [
        if (tab != 0) Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Align(alignment: Alignment.centerLeft, child: Text(titles[tab], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)))),
        Expanded(child: body),
      ])),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(
        onPressed: activeGroupId == null ? chooseGroup : () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddItemScreen(groupId: activeGroupId!, groupName: activeGroupName))); },
        icon: const Icon(Icons.add), label: const Text('Add item'),
      ) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'My Items'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}


class AddItemScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const AddItemScreen({super.key, required this.groupId, required this.groupName});
  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final rules = TextEditingController();
  final picker = ImagePicker();
  String category = 'Tools';
  String condition = 'Good';
  int maxLoanDays = 7;
  final List<XFile> photos = [];
  bool busy = false;
  String? error;

  @override
  void dispose() { title.dispose(); description.dispose(); rules.dispose(); super.dispose(); }

  Future<void> pickPhotos() async {
    try {
      final picked = await picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
      if (!mounted || picked.isEmpty) return;
      setState(() {
        final remaining = 4 - photos.length;
        photos.addAll(picked.take(remaining));
        if (picked.length > remaining) error = 'You can add up to 4 photos.';
        else error = null;
      });
    } catch (_) {
      setState(() => error = 'Could not open photos. Check the app permissions and try again.');
    }
  }

  Future<List<String>> uploadPhotos(String uid, String itemId) async {
    final urls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final bytes = await photo.readAsBytes();
      final ref = FirebaseStorage.instance.ref('items/${widget.groupId}/$uid/$itemId-$i.jpg');
      final task = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await task.ref.getDownloadURL());
    }
    return urls;
  }

  Future<void> saveItem() async {
    if (!form.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { busy = true; error = null; });
    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('items').doc();
      final imageUrls = await uploadPhotos(user.uid, ref.id);
      await ref.set({
        'id': ref.id,
        'groupId': widget.groupId,
        'ownerId': user.uid,
        'ownerName': user.displayName ?? 'Neighbor',
        'title': title.text.trim(),
        'category': category,
        'description': description.text.trim(),
        'condition': condition,
        'maxLoanDays': maxLoanDays,
        'rules': rules.text.trim(),
        'imageUrls': imageUrls,
        'available': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item shared with your group.')));
        Navigator.pop(context, true);
      }
    } on FirebaseException catch (e) {
      setState(() => error = 'Could not save item (${e.code}). Check Firestore and Storage rules.');
    } catch (_) {
      setState(() => error = 'Could not save item. Check your connection and Firebase setup.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share an item', style: TextStyle(fontWeight: FontWeight.w800))),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFE4F2E2), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [const Icon(Icons.groups_rounded, color: green, size: 28), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Visible to this group', style: TextStyle(fontWeight: FontWeight.w800)), Text(widget.groupName, maxLines: 1, overflow: TextOverflow.ellipsis)]))])),
      const SizedBox(height: 20),
      TextFormField(controller: title, textCapitalization: TextCapitalization.sentences, maxLength: 70,
        decoration: const InputDecoration(labelText: 'Item name', hintText: 'e.g. Electric drill', prefixIcon: Icon(Icons.inventory_2_outlined)),
        validator: (v) => (v == null || v.trim().length < 2) ? 'Enter an item name.' : null),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
        items: const ['Tools', 'Garden', 'Kitchen', 'Camping', 'Sports', 'Electronics', 'Party', 'Kids', 'Books', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) { if (v != null) setState(() => category = v); }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: condition, decoration: const InputDecoration(labelText: 'Condition', prefixIcon: Icon(Icons.verified_outlined)),
        items: const ['New', 'Like new', 'Good', 'Fair', 'Needs repair'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) { if (v != null) setState(() => condition = v); }),
      const SizedBox(height: 12),
      TextFormField(controller: description, maxLines: 4, maxLength: 500,
        decoration: const InputDecoration(labelText: 'Description', hintText: 'What is included? Any useful details?'),
        validator: (v) => (v == null || v.trim().length < 5) ? 'Add a short description.' : null),
      const SizedBox(height: 12),
      Text('Photos (up to 4)', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < photos.length; i++)
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(photos[i].path), width: 82, height: 82, fit: BoxFit.cover)),
            Positioned(right: 0, top: 0, child: IconButton(onPressed: busy ? null : () => setState(() => photos.removeAt(i)), icon: const Icon(Icons.cancel, color: Colors.white), style: IconButton.styleFrom(backgroundColor: Colors.black45, padding: const EdgeInsets.all(4)))),
          ]),
        if (photos.length < 4) InkWell(onTap: busy ? null : pickPhotos, borderRadius: BorderRadius.circular(12),
          child: Container(width: 82, height: 82, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_a_photo_outlined, color: green))),
      ]),
      const SizedBox(height: 18),
      Text('Maximum borrowing period: $maxLoanDays days', style: const TextStyle(fontWeight: FontWeight.w700)),
      Slider(value: maxLoanDays.toDouble(), min: 1, max: 30, divisions: 29, label: '$maxLoanDays days',
        onChanged: busy ? null : (v) => setState(() => maxLoanDays = v.round())),
      const SizedBox(height: 8),
      TextFormField(controller: rules, maxLines: 2, maxLength: 240,
        decoration: const InputDecoration(labelText: 'Borrowing notes (optional)', hintText: 'e.g. Please return clean and dry.')),
      if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))],
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: busy ? null : saveItem, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish_outlined),
        label: Text(busy ? 'Sharing item…' : 'Share with group'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54))),
      const SizedBox(height: 12),
      Text('Only members of this private group should be able to view this listing. Never include private contact details in the description.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    ])),
  );
}

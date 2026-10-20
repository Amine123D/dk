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
  bool availableOnly = false;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    activeGroupId = widget.initialGroupId;
    activeGroupName = widget.initialGroupName ?? activeGroupName;
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
        onSelected: (value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sort by $value will be enabled with the item feed.'))),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'Newest', child: Text('Newest')),
          PopupMenuItem(value: 'Nearest return date', child: Text('Nearest return date')),
          PopupMenuItem(value: 'Highest-rated owner', child: Text('Highest-rated owner')),
        ],
      ),
    ])),
    Expanded(child: emptyTab(Icons.inventory_2_outlined, 'Nothing shared yet', 'Be the first to add an item to this group. Listings will appear here when item creation is implemented.')),
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
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item creation is the next feature milestone.'))),
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

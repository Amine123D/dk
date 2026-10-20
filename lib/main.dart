import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const green = Color(0xFF2E7D32);
const photoBucket = 'lendly-item-photos';
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty) { runApp(const SetupRequiredApp()); return; }
  await Supabase.initialize(url: url, publishableKey: key);
  runApp(const LendlyApp());
}

class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Lendly setup', theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: green)),
    home: const Scaffold(body: SafeArea(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.handshake_rounded, size: 54, color: green), SizedBox(height: 16),
      Text('Lendly needs its Supabase connection', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      SizedBox(height: 10), Text('Run with --dart-define=SUPABASE_URL=YOUR_PROJECT_URL and --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY.', textAlign: TextAlign.center),
    ]))))),
  );
}

class LendlyApp extends StatelessWidget {
  const LendlyApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Lendly', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: const Color(0xFFF7F8F5),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
    home: const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: supabase.auth.onAuthStateChange,
    builder: (context, snapshot) => supabase.auth.currentSession == null ? const LoginScreen() : const GroupScreen(),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), email = TextEditingController(), password = TextEditingController();
  bool signup = false, hidePassword = true, busy = false;
  String? error;
  @override void dispose() { name.dispose(); email.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() { busy = true; error = null; });
    try {
      if (signup) {
        await supabase.auth.signUp(email: email.text.trim(), password: password.text, data: {'display_name': name.text.trim()});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Check your email if confirmation is enabled.')));
      } else {
        await supabase.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } on AuthException catch (e) { setState(() => error = e.message); }
    catch (_) { setState(() => error = 'Connection failed. Check the Supabase URL and publishable key.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> resetPassword() async {
    if (!email.text.trim().contains('@')) { setState(() => error = 'Enter your email address first.'); return; }
    try {
      await supabase.auth.resetPasswordForEmail(email.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('If reset is enabled, check your email.')));
    } on AuthException catch (e) { setState(() => error = e.message); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Form(key: form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 76, width: 76, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFE4F2E2), borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.handshake_rounded, color: green, size: 42)),
        const SizedBox(height: 22), const Text('Lendly', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), Text(signup ? 'Join your neighborhood sharing circle.' : 'Borrow more. Buy less. Get to know your neighbors.', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
        const SizedBox(height: 26),
        if (signup) ...[
          TextFormField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name.' : null),
          const SizedBox(height: 14),
        ],
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)),
          validator: (v) => (v == null || !v.trim().contains('@')) ? 'Enter a valid email.' : null),
        const SizedBox(height: 14),
        TextFormField(controller: password, obscureText: hidePassword, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(onPressed: () => setState(() => hidePassword = !hidePassword), icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
          validator: (v) => (v == null || v.length < 6) ? 'Use at least 6 characters.' : null),
        if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red))],
        const SizedBox(height: 20),
        FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(signup ? 'Create account' : 'Log in')),
        if (!signup) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: resetPassword, child: const Text('Forgot password?'))),
        TextButton(onPressed: busy ? null : () => setState(() { signup = !signup; error = null; }), child: Text(signup ? 'Already have an account? Log in' : 'New to Lendly? Create an account')),
        const SizedBox(height: 10), Text('Private sharing for people who live, learn, or spend time nearby.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ]),
    )),
  ))));

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});
  @override State<GroupScreen> createState() => _GroupScreenState();
}
class _GroupScreenState extends State<GroupScreen> {
  final code = TextEditingController(), groupName = TextEditingController();
  String type = 'Building';
  bool busy = false;
  String? error, createdCode;
  @override void dispose() { code.dispose(); groupName.dispose(); super.dispose(); }
  String makeCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
  Future<void> join() async {
    final invite = code.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(invite)) { setState(() => error = 'Enter the 6-character invite code.'); return; }
    setState(() { busy = true; error = null; });
    try {
      await supabase.rpc('lendly_join_group', params: {'p_invite_code': invite});
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    } on PostgrestException catch (e) { setState(() => error = e.message.contains('invalid_invite_code') ? 'That invite code was not found.' : 'Could not join group. Please try again.'); }
    catch (_) { setState(() => error = 'Could not connect to Supabase.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> create() async {
    if (groupName.text.trim().length < 3) { setState(() => error = 'Group name must be at least 3 characters.'); return; }
    setState(() { busy = true; error = null; });
    final invite = makeCode();
    try {
      final id = await supabase.rpc('lendly_create_group', params: {'p_name': groupName.text.trim(), 'p_group_type': type, 'p_invite_code': invite});
      if (!mounted) return;
      setState(() => createdCode = invite);
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Your group is ready!'),
        content: SelectableText('Share this invite code with your group: ' + invite),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue'))],
      ));
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeScreen(initialGroupId: id.toString(), initialGroupName: groupName.text.trim())), (_) => false);
    } on PostgrestException catch (e) { setState(() => error = e.message.contains('duplicate key') ? 'Please try again to create a group.' : 'Could not create group. Check Supabase setup.'); }
    catch (_) { setState(() => error = 'Could not connect to Supabase.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your sharing circle', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: () => supabase.auth.signOut(), icon: const Icon(Icons.logout), tooltip: 'Log out')]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFFE4F2E2), borderRadius: BorderRadius.circular(24)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.groups_rounded, color: green, size: 36), SizedBox(height: 12),
          Text('Sharing starts nearby.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), SizedBox(height: 8), Text('Create a private group or join one with an invite code from someone you know.')])),
      const SizedBox(height: 18),
      Card(color: Colors.white, elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Join a group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Have a 6-character invite code?'), const SizedBox(height: 12),
        TextField(controller: code, maxLength: 6, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Invite code', prefixIcon: Icon(Icons.key_outlined), counterText: '')),
        const SizedBox(height: 10), FilledButton(onPressed: busy ? null : join, child: const Text('Join with code')),
      ]))),
      const SizedBox(height: 14),
      Card(color: Colors.white, elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Create a group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('For your building, street, school, or club.'),
        const SizedBox(height: 12), TextField(controller: groupName, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Group name', prefixIcon: Icon(Icons.home_work_outlined))),
        const SizedBox(height: 12), DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Group type'),
          items: const ['Building','Street','School','Club','Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setState(() => type = v); }),
        if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))],
        const SizedBox(height: 12), FilledButton.tonalIcon(onPressed: busy ? null : create, icon: const Icon(Icons.add_home_work_outlined), label: const Text('Create a group')),
      ]))),
      if (busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
      const SizedBox(height: 12), Text('Signed in as ' + (supabase.auth.currentUser?.email ?? 'your account'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    ]),
  );
}

class HomeScreen extends StatefulWidget {
  final String? initialGroupId, initialGroupName;
  const HomeScreen({super.key, this.initialGroupId, this.initialGroupName});
  @override State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  String? activeGroupId;
  String activeGroupName = 'Your sharing circle';
  String category = 'All', sortBy = 'Newest';
  bool availableOnly = false, loadingGroups = true;
  final search = TextEditingController();
  List<Map<String, dynamic>> groups = [];
  @override void initState() { super.initState(); activeGroupId = widget.initialGroupId; activeGroupName = widget.initialGroupName ?? activeGroupName; _loadGroups(); }
  @override void dispose() { search.dispose(); super.dispose(); }

  Future<void> _loadGroups() async {
    try {
      final memberships = await supabase.from('lendly_group_members').select('group_id').eq('user_id', supabase.auth.currentUser!.id);
      final ids = memberships.map((e) => e['group_id'].toString()).toList();
      if (ids.isEmpty) { if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const GroupScreen()), (_) => false); return; }
      final rows = await supabase.from('lendly_groups').select('id,name').inFilter('id', ids);
      if (!mounted) return;
      setState(() {
        groups = List<Map<String, dynamic>>.from(rows);
        if (activeGroupId == null || !groups.any((g) => g['id'].toString() == activeGroupId)) { activeGroupId = groups.first['id'].toString(); activeGroupName = groups.first['name'].toString(); }
        loadingGroups = false;
      });
    } catch (_) { if (mounted) setState(() => loadingGroups = false); }
  }
  Widget emptyTab(IconData icon, String title, String message) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFFE4F2E2), shape: BoxShape.circle), child: Icon(icon, color: green, size: 42)),
    const SizedBox(height: 18), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
  ])));
  Future<List<Map<String, dynamic>>> loadItems() async {
    if (activeGroupId == null) return [];
    final rows = await supabase.from('lendly_items').select().eq('group_id', activeGroupId!).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
  Future<String?> signedPhoto(String path) async { try { return await supabase.storage.from(photoBucket).createSignedUrl(path, 3600); } catch (_) { return null; } }
  Widget photo(String? path, {double width = 110, double height = 125}) {
    if (path == null || path.isEmpty) return Container(width: width, height: height, color: const Color(0xFFE4F2E2), child: const Icon(Icons.inventory_2_outlined, size: 36, color: green));
    return FutureBuilder<String?>(future: signedPhoto(path), builder: (context, snap) => SizedBox(width: width, height: height,
      child: snap.data == null ? const ColoredBox(color: Color(0xFFE4F2E2), child: Icon(Icons.image_outlined, color: green))
        : Image.network(snap.data!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFE4F2E2), child: Icon(Icons.broken_image_outlined, color: green)))));
  }
  Widget buildHomeFeed() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: TextField(controller: search, decoration: InputDecoration(hintText: 'Search things to borrow', prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton(onPressed: () => setState(() => search.clear()), icon: const Icon(Icons.close))), onChanged: (_) => setState(() {}))),
    SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      children: ['All','Tools','Garden','Kitchen','Camping','Sports','Electronics','Party','Kids','Books','Other'].map((v) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(label: Text(v), selected: category == v, onSelected: (_) => setState(() => category = v))).toList())),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [
      FilterChip(label: const Text('Available only'), avatar: const Icon(Icons.check_circle_outline, size: 18), selected: availableOnly, onSelected: (v) => setState(() => availableOnly = v)),
      const Spacer(), PopupMenuButton<String>(tooltip: 'Sort items', icon: const Icon(Icons.sort), onSelected: (v) => setState(() => sortBy = v),
        itemBuilder: (_) => const [PopupMenuItem(value: 'Newest', child: Text('Newest')), PopupMenuItem(value: 'Title A–Z', child: Text('Title A–Z'))]),
    ])),
    Expanded(child: loadingGroups ? const Center(child: CircularProgressIndicator()) : activeGroupId == null ? emptyTab(Icons.groups_outlined, 'Choose a group', 'Join or create a private group first.')
      : FutureBuilder<List<Map<String, dynamic>>>(future: loadItems(), builder: (context, snapshot) {
        if (snapshot.hasError) return emptyTab(Icons.cloud_off_outlined, 'Could not load items', 'Check your Supabase connection and policies.');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final q = search.text.trim().toLowerCase();
        final items = snapshot.data!.where((d) => (q.isEmpty || d['title'].toString().toLowerCase().contains(q) || d['description'].toString().toLowerCase().contains(q))
          && (category == 'All' || d['category'] == category) && (!availableOnly || d['available'] == true)).toList();
        if (sortBy == 'Title A–Z') items.sort((a,b) => a['title'].toString().compareTo(b['title'].toString()));
        if (items.isEmpty) return emptyTab(Icons.inventory_2_outlined, 'Nothing shared yet', q.isEmpty ? 'Be the first to add an item to this group.' : 'No items match your search or filters.');
        return RefreshIndicator(onRefresh: () async { setState(() {}); await loadItems(); }, child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), itemCount: items.length, itemBuilder: (context, i) {
          final d = items[i]; final photos = List<String>.from(d['image_paths'] ?? const []);
          return Card(margin: const EdgeInsets.only(bottom: 12), clipBehavior: Clip.antiAlias, color: Colors.white, elevation: 0, child: InkWell(
            onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(d['title'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
              Text(d['category'].toString() + ' · ' + d['condition'].toString(), style: TextStyle(color: Colors.grey.shade700)),
              if (photos.isNotEmpty) ...[const SizedBox(height: 14), SizedBox(height: 190, child: ListView(scrollDirection: Axis.horizontal, children: photos.map((p) => Padding(padding: const EdgeInsets.only(right: 8),
                child: FutureBuilder<String?>(future: signedPhoto(p), builder: (context, snap) => snap.data == null ? const SizedBox(width: 220, child: Icon(Icons.image_outlined)) : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(snap.data!, width: 220, fit: BoxFit.cover)))).toList()))],
              const SizedBox(height: 14), Text((d['description'] ?? '').toString()), const SizedBox(height: 12), Text('Loan period: up to ' + d['max_loan_days'].toString() + ' days'),
              if ((d['rules'] ?? '').toString().trim().isNotEmpty) ...[const SizedBox(height: 8), Text('Owner notes: ' + d['rules'].toString())],
              const SizedBox(height: 16), FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ])))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              photo(photos.isEmpty ? null : photos.first),
              Expanded(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['title'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 5), Text(d['category'].toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                const SizedBox(height: 6), Text((d['description'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8), Text('Up to ' + d['max_loan_days'].toString() + ' days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]))),
            ])));
        }));
      })),
  ]);
  Future<void> chooseGroup() async {
    if (groups.isEmpty) { await _loadGroups(); return; }
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
      const Text('Switch sharing group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      for (final g in groups) ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFE4F2E2), child: Icon(Icons.groups_rounded, color: green)),
        title: Text(g['name'].toString()), trailing: g['id'].toString() == activeGroupId ? const Icon(Icons.check_circle, color: green) : null,
        onTap: () { setState(() { activeGroupId = g['id'].toString(); activeGroupName = g['name'].toString(); }); Navigator.pop(ctx); }),
      ListTile(leading: const Icon(Icons.add), title: const Text('Join or create another group'), onTap: () { Navigator.pop(ctx); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupScreen())); }),
    ])));
  }
  @override Widget build(BuildContext context) {
    final titles = ['Home','My Items','Requests','Profile'];
    final body = switch (tab) {
      0 => buildHomeFeed(),
      1 => emptyTab(Icons.inventory_2_outlined, 'My items', 'Your listings and borrowed items will be added in the next milestone.'),
      2 => emptyTab(Icons.inbox_outlined, 'Requests', 'Borrowing requests and pickup details will be added next.'),
      _ => emptyTab(Icons.person_outline, 'Your profile', 'Profile, favorites, and trust score will be added next.'),
    };
    return Scaffold(
      appBar: AppBar(titleSpacing: 16, title: InkWell(borderRadius: BorderRadius.circular(12), onTap: chooseGroup, child: Row(mainAxisSize: MainAxisSize.min, children: [
        const CircleAvatar(radius: 18, backgroundColor: Color(0xFFE4F2E2), child: Icon(Icons.groups_rounded, color: green, size: 21)), const SizedBox(width: 10),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(activeGroupName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Text('Private sharing group', style: TextStyle(fontSize: 11, color: Colors.grey))])), const Icon(Icons.keyboard_arrow_down),
      ])), actions: [IconButton(onPressed: () => supabase.auth.signOut(), icon: const Icon(Icons.logout_rounded), tooltip: 'Log out')]),
      body: SafeArea(child: Column(children: [if (tab != 0) Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Align(alignment: Alignment.centerLeft, child: Text(titles[tab], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)))), Expanded(child: body)])),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(onPressed: activeGroupId == null ? null : () async {
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AddItemScreen(groupId: activeGroupId!, groupName: activeGroupName)));
        if (saved == true && mounted) setState(() {});
      }, icon: const Icon(Icons.add), label: const Text('Add item')) : null,
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'My Items'),
        NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'Requests'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ]),
    );
  }
}

class AddItemScreen extends StatefulWidget {
  final String groupId, groupName;
  const AddItemScreen({super.key, required this.groupId, required this.groupName});
  @override State<AddItemScreen> createState() => _AddItemScreenState();
}
class _AddItemScreenState extends State<AddItemScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), description = TextEditingController(), rules = TextEditingController();
  final picker = ImagePicker();
  String category = 'Tools', condition = 'Good';
  int maxLoanDays = 7;
  final List<XFile> photos = [];
  bool busy = false;
  String? error;
  @override void dispose() { title.dispose(); description.dispose(); rules.dispose(); super.dispose(); }
  Future<void> pickPhotos() async {
    try {
      final picked = await picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
      if (!mounted || picked.isEmpty) return;
      setState(() { final remaining = 4 - photos.length; photos.addAll(picked.take(remaining)); error = picked.length > remaining ? 'You can add up to 4 photos.' : null; });
    } catch (_) { setState(() => error = 'Could not open photos. Try again.'); }
  }
  Future<void> saveItem() async {
    if (!form.currentState!.validate()) return;
    final user = supabase.auth.currentUser; if (user == null) return;
    setState(() { busy = true; error = null; });
    final uploaded = <String>[];
    try {
      final inserted = await supabase.from('lendly_items').insert({
        'group_id': widget.groupId, 'owner_id': user.id, 'owner_name': (user.userMetadata?['display_name'] ?? user.email?.split('@').first ?? 'Neighbor').toString(),
        'title': title.text.trim(), 'category': category, 'description': description.text.trim(), 'condition': condition,
        'max_loan_days': maxLoanDays, 'rules': rules.text.trim(), 'image_paths': <String>[], 'available': true,
      }).select('id').single();
      final paths = <String>[];
      for (var i = 0; i < photos.length; i++) {
        final path = widget.groupId + '/' + user.id + '/' + inserted['id'].toString() + '-' + i.toString() + '.jpg';
        await supabase.storage.from(photoBucket).uploadBinary(path, await photos[i].readAsBytes(), fileOptions: const FileOptions(contentType: 'image/jpeg'));
        uploaded.add(path); paths.add(path);
      }
      await supabase.from('lendly_items').update({'image_paths': paths}).eq('id', inserted['id']);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item shared with your group.'))); Navigator.pop(context, true); }
    } on StorageException catch (e) {
      for (final path in uploaded) { try { await supabase.storage.from(photoBucket).remove([path]); } catch (_) {} }
      setState(() => error = 'Photo upload failed: ' + e.message);
    } on PostgrestException catch (e) {
      for (final path in uploaded) { try { await supabase.storage.from(photoBucket).remove([path]); } catch (_) {} }
      setState(() => error = 'Could not save item: ' + e.message);
    } catch (_) {
      for (final path in uploaded) { try { await supabase.storage.from(photoBucket).remove([path]); } catch (_) {} }
      setState(() => error = 'Could not save item. Check connection and Supabase setup.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Share an item', style: TextStyle(fontWeight: FontWeight.w800))),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFE4F2E2), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [const Icon(Icons.groups_rounded, color: green, size: 28), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Visible to this group', style: TextStyle(fontWeight: FontWeight.w800)), Text(widget.groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]))])),
      const SizedBox(height: 20),
      TextFormField(controller: title, textCapitalization: TextCapitalization.sentences, maxLength: 70, decoration: const InputDecoration(labelText: 'Item name', hintText: 'e.g. Electric drill', prefixIcon: Icon(Icons.inventory_2_outlined)),
        validator: (v) => (v == null || v.trim().length < 2) ? 'Enter an item name.' : null),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
        items: const ['Tools','Garden','Kitchen','Camping','Sports','Electronics','Party','Kids','Books','Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setState(() => category = v); }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: condition, decoration: const InputDecoration(labelText: 'Condition', prefixIcon: Icon(Icons.verified_outlined)),
        items: const ['New','Like new','Good','Fair','Needs repair'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setState(() => condition = v); }),
      const SizedBox(height: 12),
      TextFormField(controller: description, maxLines: 4, maxLength: 500, decoration: const InputDecoration(labelText: 'Description'),
        validator: (v) => (v == null || v.trim().length < 5) ? 'Add a short description.' : null),
      const SizedBox(height: 12), const Text('Photos (up to 4)', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < photos.length; i++) Stack(children: [
          FutureBuilder<List<int>>(future: photos[i].readAsBytes(), builder: (context, snap) => ClipRRect(borderRadius: BorderRadius.circular(12),
            child: snap.data == null ? Container(width: 82, height: 82, color: const Color(0xFFE4F2E2)) : Image.memory(snap.data!, width: 82, height: 82, fit: BoxFit.cover))),
          Positioned(right: 0, top: 0, child: IconButton(onPressed: busy ? null : () => setState(() => photos.removeAt(i)), icon: const Icon(Icons.cancel, color: Colors.white), style: IconButton.styleFrom(backgroundColor: Colors.black45, padding: const EdgeInsets.all(4)))),
        ]),
        if (photos.length < 4) InkWell(onTap: busy ? null : pickPhotos, borderRadius: BorderRadius.circular(12), child: Container(width: 82, height: 82,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_a_photo_outlined, color: green))),
      ]),
      const SizedBox(height: 18), Text('Maximum borrowing period: ' + maxLoanDays.toString() + ' days', style: const TextStyle(fontWeight: FontWeight.w700)),
      Slider(value: maxLoanDays.toDouble(), min: 1, max: 30, divisions: 29, label: maxLoanDays.toString() + ' days', onChanged: busy ? null : (v) => setState(() => maxLoanDays = v.round())),
      const SizedBox(height: 8), TextFormField(controller: rules, maxLines: 2, maxLength: 240, decoration: const InputDecoration(labelText: 'Borrowing notes (optional)')),
      if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))],
      const SizedBox(height: 14), FilledButton.icon(onPressed: busy ? null : saveItem, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish_outlined),
        label: Text(busy ? 'Sharing item…' : 'Share with group'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54))),
      const SizedBox(height: 12), Text('Only members of this private group can access the listing. Do not include private contact details.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    ])));
}

import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

void main() => runApp(const NidalApp());
const cyan = Color(0xff22d3ee);
const bg = Color(0xff04070f);
const card = Color(0xff0c1526);

class NidalApp extends StatefulWidget {
  const NidalApp({super.key});
  @override
  State<NidalApp> createState() => _NidalAppState();
}

class _NidalAppState extends State<NidalApp> {
  bool ar = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Nidal Games',
    locale: Locale(ar ? 'ar' : 'en'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: Color(0xff2563eb),
        surface: card,
      ),
      useMaterial3: true,
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: card,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    ),
    home: Home(ar: ar, changeLanguage: () => setState(() => ar = !ar)),
  );
}

class Home extends StatefulWidget {
  final bool ar;
  final VoidCallback changeLanguage;
  const Home({super.key, required this.ar, required this.changeLanguage});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final api = Api(const String.fromEnvironment('API_BASE_URL'));
  List<dynamic> games = [],
      categories = [],
      favorites = [],
      history = [],
      collections = [],
      downloads = [],
      activity = [],
      recommendations = [];
  Map<String, dynamic>? user;
  bool loading = true, free = false, sales = false;
  String search = '',
      category = '',
      sort = 'newest',
      collection = '',
      error = '';
  int page = 0;
  Timer? debounce;
  String tr(String a, String e) => widget.ar ? a : e;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    api.base = prefs.getString('backend') ?? api.base;
    await load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    api.close();
    super.dispose();
  }

  Future<void> guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      if (api.configured) {
        final q = Uri(
          queryParameters: {
            'search': search,
            'category': category,
            'sort': sort,
            if (free) 'free': '1',
            if (sales) 'discount': '1',
          },
        ).query;
        final res = await api.request('games/?$q');
        final all = List<dynamic>.from(res['results']);
        var next = res['next'];
        var pageNo = 2;
        while (next != null && pageNo <= 100) {
          final more = await api.request('games/?$q&page=$pageNo');
          all.addAll(more['results']);
          next = more['next'];
          pageNo++;
        }
        res['results'] = all;
        final cat = await api.request('categories/');
        final me = await api.request('me/');
        if (mounted) {
          setState(() {
            games = res['results'];
            categories = cat;
            user = me['user'];
            error = '';
          });
        }
        if (user != null) await syncLibrary();
      } else {
        final data = jsonDecode(
          await rootBundle.loadString('assets/catalog.json'),
        );
        if (mounted) {
          setState(() {
            games = data['games'];
            categories = data['categories'];
            error = '';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> syncLibrary() async {
    final l = await api.request('library/');
    final c = await api.request('collections/');
    final d = await api.request('downloads/');
    final a = await api.request('activity/');
    final r = await api.request('recommendations/');
    if (mounted) {
      setState(() {
        favorites = l['favorites'];
        history = l['history'];
        collections = c['results'];
        downloads = d['results'];
        activity = a;
        recommendations = r;
      });
    }
  }

  Future<bool> requireUser() async {
    if (user != null) return true;
    await auth();
    return user != null;
  }

  Future<void> favorite(dynamic g) async {
    if (!await requireUser()) return;
    await guard(() async {
      final exists = favorites.any((x) => x['id'] == g['id']);
      await api.request(
        'games/${g['slug']}/favorite/',
        exists ? 'DELETE' : 'POST',
      );
      await syncLibrary();
    });
  }

  Future<void> external(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['https', 'http'].contains(uri.scheme)) {
      throw Exception('Invalid source URL');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Unable to open official source');
    }
  }

  Future<void> source(dynamic g) async {
    await guard(() async {
      String url = g['store_url'].toString().isNotEmpty
          ? g['store_url']
          : g['official_url'];
      if (user != null && api.configured) {
        final r = await api.request('games/${g['slug']}/open_source/', 'POST');
        url = r['url'];
        await syncLibrary();
      }
      await external(url);
    });
  }

  Future<void> settings() async {
    final controller = TextEditingController(text: api.base);
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('إعداد الخادم', 'Backend settings')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(
                'اربط عنوان HTTPS لخادمك لتفعيل الحساب والمزامنة. بدون خادم يمكنك تصفح كتالوج محفوظ فقط.',
                'Connect your HTTPS backend for accounts and sync. Without a backend, only the bundled catalog is available.',
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: 'https://api.example.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: Text(tr('حفظ واختبار', 'Save & test')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (value.isNotEmpty &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'استخدم عنوان HTTPS صالحاً بلا بيانات دخول',
                'Use a valid HTTPS URL without credentials',
              ),
            ),
          ),
        );
      }
      return;
    }
    api.base = value.replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend', api.base);
    setState(() {
      user = null;
      favorites = [];
      history = [];
      collections = [];
    });
    await load();
  }

  Future<void> auth() async {
    if (!api.configured) {
      await settings();
      return;
    }
    if (!mounted) return;
    final name = TextEditingController(), pass = TextEditingController();
    bool register = false, busy = false;
    String err = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            register
                ? tr('حساب جديد', 'Create account')
                : tr('تسجيل الدخول', 'Sign in'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: tr('اسم المستخدم', 'Username'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: tr('كلمة المرور', 'Password'),
                  ),
                ),
                if (err.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      err,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                TextButton(
                  onPressed: () => update(() => register = !register),
                  child: Text(
                    register
                        ? tr('لدي حساب', 'I have an account')
                        : tr('إنشاء حساب', 'Create account'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      update(() => busy = true);
                      try {
                        await api.request(
                          'auth/${register ? 'register' : 'login'}/',
                          'POST',
                          {'username': name.text.trim(), 'password': pass.text},
                        );
                        await load();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        update(() => err = e.toString());
                      }
                      if (ctx.mounted) update(() => busy = false);
                    },
              child: Text(tr('متابعة', 'Continue')),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    pass.dispose();
  }

  Future<void> newCollection() async {
    if (!await requireUser()) return;
    if (!mounted) return;
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('قائمة جديدة', 'New collection')),
        content: TextField(controller: ctl, maxLength: 100),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c, ctl.text.trim()),
            child: Text(tr('إنشاء', 'Create')),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (name == null || name.isEmpty) return;
    await guard(() async {
      await api.request('collections/', 'POST', {'name': name, 'games': []});
      await syncLibrary();
    });
  }

  Widget gameCard(dynamic g) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => details(g),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                g['cover'].toString().isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.sports_esports,
                          size: 60,
                          color: cyan,
                        ),
                      )
                    : Image.network(
                        g['cover'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => const Center(
                          child: Icon(
                            Icons.sports_esports,
                            size: 60,
                            color: cyan,
                          ),
                        ),
                      ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.all(5),
                    child: Text(
                      g['is_free'] == true
                          ? tr('مجانية', 'FREE')
                          : tr('متجر رسمي', 'OFFICIAL'),
                      style: const TextStyle(fontSize: 9, color: cyan),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 2, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    g['title'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => favorite(g),
                  icon: Icon(
                    favorites.any((x) => x['id'] == g['id'])
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 17,
                    color: cyan,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Text(
              (g['platforms'] as List).join(' / '),
              maxLines: 1,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 9),
            ),
          ),
        ],
      ),
    ),
  );
  Widget grid(List<dynamic> list) => list.isEmpty
      ? Padding(
          padding: const EdgeInsets.all(36),
          child: Center(
            child: Text(tr('لا توجد ألعاب هنا بعد', 'No games here yet')),
          ),
        )
      : LayoutBuilder(
          builder: (c, b) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: b.maxWidth > 900
                  ? 4
                  : b.maxWidth > 600
                  ? 3
                  : 2,
              childAspectRatio: .98,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (c, i) => gameCard(list[i]),
          ),
        );
  @override
  Widget build(BuildContext context) {
    List<dynamic> visible = games;
    if (!api.configured) {
      visible = games
          .where(
            (g) =>
                (search.isEmpty ||
                    '${g['title']} ${g['description']}'.toLowerCase().contains(
                      search.toLowerCase(),
                    )) &&
                (!free || g['is_free'] == true) &&
                (!sales || (g['discount_percent'] ?? 0) > 0) &&
                (category.isEmpty ||
                    (g['categories'] as List).any(
                      (c) => c['slug'] == category,
                    )),
          )
          .toList();
      if (sort == 'title') {
        visible.sort((a, b) => a['title'].toString().compareTo(b['title']));
      }
    }
    final lib = collection.isEmpty
        ? favorites
        : collection == 'history'
        ? history
        : [
            for (final c in collections)
              if (c['id'].toString() == collection)
                ...((c['games_detail'] ?? const []) as List),
          ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        title: const Row(
          children: [
            Icon(Icons.sports_esports, color: cyan),
            SizedBox(width: 9),
            Text(
              'NIDAL GAMES',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Backend',
            onPressed: settings,
            icon: const Icon(Icons.settings_outlined),
          ),
          TextButton(
            onPressed: widget.changeLanguage,
            child: Text(widget.ar ? 'EN' : 'عربي'),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: card,
        selectedIndex: page,
        onDestinationSelected: (n) async {
          if (n > 0 && !await requireUser()) return;
          setState(() => page = n);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            label: tr('اكتشف', 'Discover'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view),
            label: tr('مكتبتي', 'Library'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: tr('حسابي', 'Profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (!api.configured)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: card,
                  border: Border.all(color: cyan.withValues(alpha: .3)),
                ),
                child: Text(
                  tr(
                    'وضع التصفح • كتالوج رسمي محفوظ. الحساب والمزامنة يحتاجان ربط خادم HTTPS من الإعدادات.',
                    'BROWSE MODE • Saved official catalog. Accounts and sync need an HTTPS backend in Settings.',
                  ),
                  style: const TextStyle(fontSize: 11, color: cyan),
                ),
              ),
            if (error.isNotEmpty) ...[
              Text(error, style: const TextStyle(color: Colors.redAccent)),
              TextButton(
                onPressed: load,
                child: Text(tr('إعادة المحاولة', 'Retry')),
              ),
            ],
            if (loading) const LinearProgressIndicator(),
            if (page == 0) ...[
              Text(
                tr('عالمك التالي يبدأ هنا', 'YOUR NEXT WORLD'),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  'اكتشف. اجمع. العب. من المصادر الرسمية فقط.',
                  'Discover. Collect. Play. Official sources only.',
                ),
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
              const SizedBox(height: 20),
              TextField(
                onChanged: (s) {
                  setState(() => search = s);
                  debounce?.cancel();
                  if (api.configured) {
                    debounce = Timer(const Duration(milliseconds: 400), load);
                  }
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: tr(
                    'ابحث عن لعبتك القادمة...',
                    'Find your next game...',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (visible.isNotEmpty &&
                  search.isEmpty &&
                  category.isEmpty &&
                  !free &&
                  !sales)
                GestureDetector(
                  onTap: () => details(visible.first),
                  child: Container(
                    height: 245,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      border: Border.all(color: cyan.withValues(alpha: .4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (visible.first['cover'].toString().isNotEmpty)
                          Image.network(
                            visible.first['cover'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) => const SizedBox(),
                          ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, bg],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                tr('اختيار المحرر / 01', 'EDITOR’S PICK / 01'),
                                style: const TextStyle(
                                  color: cyan,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                visible.first['title'],
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => details(visible.first),
                                child: Text(
                                  tr('استكشف اللعبة ↗', 'Explore game ↗'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text(tr('مجانية', 'Free')),
                    selected: free,
                    onSelected: (v) {
                      setState(() => free = v);
                      if (api.configured) load();
                    },
                  ),
                  FilterChip(
                    label: Text(tr('تخفيضات', 'On sale')),
                    selected: sales,
                    onSelected: (v) {
                      setState(() => sales = v);
                      if (api.configured) load();
                    },
                  ),
                  DropdownButton<String>(
                    value: sort,
                    items: [
                      DropdownMenuItem(
                        value: 'newest',
                        child: Text(tr('الأحدث', 'Newest')),
                      ),
                      DropdownMenuItem(
                        value: 'popular',
                        child: Text(tr('الأكثر شعبية', 'Popular')),
                      ),
                      const DropdownMenuItem(
                        value: 'title',
                        child: Text('A → Z'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => sort = v!);
                      if (api.configured) load();
                    },
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(tr('الكل', 'All')),
                      selected: category.isEmpty,
                      onSelected: (_) {
                        setState(() => category = '');
                        if (api.configured) load();
                      },
                    ),
                    ...categories.map(
                      (c) => Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: ChoiceChip(
                          label: Text(widget.ar ? c['name_ar'] : c['name']),
                          selected: category == c['slug'],
                          onSelected: (_) {
                            setState(() => category = c['slug']);
                            if (api.configured) load();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              grid(visible),
              if (recommendations.isNotEmpty) ...[
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('مقترحة لك', 'For you'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('تحديث الاقتراحات', 'Refresh suggestions'),
                      icon: const Icon(Icons.refresh, color: cyan),
                      onPressed: () => syncLibrary(),
                    ),
                  ],
                ),
                grid(recommendations),
              ],
            ] else if (page == 1) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('مكتبتي', 'My library'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: newCollection,
                    icon: const Icon(Icons.add_box_outlined, color: cyan),
                  ),
                ],
              ),
              Wrap(
                spacing: 7,
                children: [
                  ChoiceChip(
                    label: Text(tr('المفضلة', 'Favorites')),
                    selected: collection.isEmpty,
                    onSelected: (_) => setState(() => collection = ''),
                  ),
                  ChoiceChip(
                    label: Text(tr('شاهدتها', 'Viewed')),
                    selected: collection == 'history',
                    onSelected: (_) => setState(() => collection = 'history'),
                  ),
                  ...collections.map(
                    (c) => InputChip(
                      label: Text(c['name']),
                      selected: collection == c['id'].toString(),
                      onPressed: () =>
                          setState(() => collection = c['id'].toString()),
                      onDeleted: () => guard(() async {
                        await api.request('collections/${c['id']}/', 'DELETE');
                        setState(() => collection = '');
                        await syncLibrary();
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              grid(lib),
              const SizedBox(height: 25),
              Text(
                tr('سجل التحميل', 'Download history'),
                style: const TextStyle(fontSize: 22),
              ),
              Text(
                tr(
                  'المصادر الخارجية لا تدعم تتبع النسبة. علّم الملف كمحمّل بنفسك.',
                  'External sources do not expose progress. Mark completion yourself.',
                ),
                style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
              ),
              ...downloads.map(
                (d) => ListTile(
                  title: Text(d['game_detail']['title']),
                  subtitle: Text(d['status']),
                  trailing: d['status'] == 'downloaded'
                      ? const Icon(Icons.check, color: cyan)
                      : IconButton(
                          icon: const Icon(Icons.download_done),
                          onPressed: () => guard(() async {
                            await api.request(
                              'downloads/${d['id']}/complete/',
                              'POST',
                            );
                            await syncLibrary();
                          }),
                        ),
                ),
              ),
            ] else ...[
              Text(
                user?['username'] ?? '',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 15),
              ProfileForm(api: api, user: user, ar: widget.ar, onSave: load),
              if (user?['is_staff'] == true)
                TextButton(
                  onPressed: () => external('${api.base}/admin/'),
                  child: Text(tr('لوحة الإدارة ↗', 'Admin dashboard ↗')),
                ),
              TextButton(
                onPressed: () => guard(() async {
                  await api.request('auth/logout/', 'POST');
                  setState(() {
                    user = null;
                    page = 0;
                    favorites = [];
                    collections = [];
                  });
                }),
                child: Text(tr('تسجيل الخروج', 'Sign out')),
              ),
              const Divider(),
              Text(
                tr('سجل النشاط', 'Activity log'),
                style: const TextStyle(fontSize: 22),
              ),
              ...activity
                  .take(30)
                  .map(
                    (a) => ListTile(
                      leading: const Icon(Icons.history, size: 19),
                      title: Text(a['game_title'] ?? a['action']),
                      subtitle: Text(
                        '${a['action']} · ${a['created_at']}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 30),
            const Divider(),
            Center(
              child: Text(
                tr(
                  'NIDAL GAMES • الحقوق لأصحابها',
                  'NIDAL GAMES • All game rights belong to their owners',
                ),
                style: const TextStyle(color: Colors.blueGrey, fontSize: 9),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> details(dynamic g) async {
    List<dynamic> reviews = [], similar = [];
    if (api.configured) {
      await guard(() async {
        reviews = await api.request('games/${g['slug']}/reviews/');
        similar = await api.request('games/${g['slug']}/similar/');
        if (user != null) {
          await api.request('games/${g['slug']}/viewed/', 'POST');
          await syncLibrary();
        }
      });
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text(g['title'])),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (g['cover'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    g['cover'],
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => const SizedBox(height: 80),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                g['title'],
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.ar && g['description_ar'].toString().isNotEmpty
                    ? g['description_ar']
                    : g['description'],
                style: const TextStyle(height: 1.8, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => source(g),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(tr('المصدر الرسمي', 'Official source')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => favorite(g),
                    icon: const Icon(Icons.favorite_border),
                    label: Text(tr('المفضلة', 'Favorite')),
                  ),
                  if (user != null)
                    OutlinedButton(
                      onPressed: () => guard(() async {
                        if (collections.isEmpty) {
                          await newCollection();
                          return;
                        }
                        if (!ctx.mounted) return;
                        final id = await showDialog<int>(
                          context: ctx,
                          builder: (c) => SimpleDialog(
                            title: Text(tr('أضف لقائمة', 'Add to collection')),
                            children: collections
                                .map(
                                  (x) => SimpleDialogOption(
                                    onPressed: () => Navigator.pop(c, x['id']),
                                    child: Text(x['name']),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                        if (id != null) {
                          final col = collections.firstWhere(
                            (x) => x['id'] == id,
                          );
                          await api.request('collections/$id/', 'PATCH', {
                            'games': {
                              ...col['games'] as List,
                              g['id'],
                            }.toList(),
                          });
                          await syncLibrary();
                        }
                      }),
                      child: Text(tr('قائمة +', 'Collection +')),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ...[
                ['المطور / Developer', g['developer']],
                ['الناشر / Publisher', g['publisher']],
                ['المنصات / Platforms', (g['platforms'] as List).join(' / ')],
                ['الإصدار / Release', g['release_date']],
                ['الحجم / Size', g['size_label']],
              ].map(
                (x) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    x[0].toString(),
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 11,
                    ),
                  ),
                  subtitle: Text(
                    x[1] == null || x[1].toString().isEmpty
                        ? tr('راجع المصدر الرسمي', 'See official source')
                        : x[1].toString(),
                  ),
                ),
              ),
              const Divider(),
              Text(
                tr('متطلبات التشغيل', 'System requirements'),
                style: const TextStyle(fontSize: 21),
              ),
              ...((g['requirements'] as Map?) ?? {}).entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(fontSize: 12, height: 1.8),
                  ),
                ),
              ),
              if ((g['screenshots'] as List).isNotEmpty)
                SizedBox(
                  height: 150,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: (g['screenshots'] as List)
                        .map<Widget>(
                          (s) => Padding(
                            padding: const EdgeInsets.all(4),
                            child: Image.network(
                              s,
                              width: 240,
                              fit: BoxFit.cover,
                              errorBuilder: (_, e, st) =>
                                  const SizedBox(width: 30),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (g['trailer'].toString().isNotEmpty)
                TextButton.icon(
                  onPressed: () => guard(() => external(g['trailer'])),
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(tr('العرض الرسمي', 'Official trailer')),
                ),
              const SizedBox(height: 20),
              Text(
                tr('التقييمات', 'Reviews'),
                style: const TextStyle(fontSize: 22),
              ),
              ...reviews.map(
                (r) => ListTile(
                  title: Text('${r['username']} · ${r['rating']} ★'),
                  subtitle: Text(r['text']),
                ),
              ),
              FilledButton(
                onPressed: () => review(g),
                child: Text(tr('اكتب تقييمك', 'Write a review')),
              ),
              if (similar.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  tr('ألعاب مشابهة', 'Similar games'),
                  style: const TextStyle(fontSize: 21),
                ),
                ...similar.map(
                  (s) => ListTile(
                    title: Text(s['title']),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => details(s),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => guard(
                  () => external(
                    g['source_url'].toString().isEmpty
                        ? g['official_url']
                        : g['source_url'],
                  ),
                ),
                child: Text(
                  tr('بيانات من: ${g['source']}', 'Data from: ${g['source']}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> review(dynamic g) async {
    if (!await requireUser()) return;
    if (!mounted) return;
    final text = TextEditingController();
    int rating = 5;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(tr('تقييم اللعبة', 'Review game')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: rating,
                items: [1, 2, 3, 4, 5]
                    .map((i) => DropdownMenuItem(value: i, child: Text('$i ★')))
                    .toList(),
                onChanged: (v) => update(() => rating = v!),
              ),
              TextField(
                controller: text,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: tr('رأيك', 'Your thoughts'),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => guard(() async {
                await api.request('games/${g['slug']}/reviews/', 'POST', {
                  'rating': rating,
                  'text': text.text,
                });
                if (c.mounted) Navigator.pop(c);
              }),
              child: Text(tr('حفظ', 'Save')),
            ),
          ],
        ),
      ),
    );
    text.dispose();
  }
}

class ProfileForm extends StatefulWidget {
  final Api api;
  final Map<String, dynamic>? user;
  final bool ar;
  final Future<void> Function() onSave;
  const ProfileForm({
    super.key,
    required this.api,
    required this.user,
    required this.ar,
    required this.onSave,
  });
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final name = TextEditingController(
    text: widget.user?['profile']?['display_name'] ?? '',
  );
  late final bio = TextEditingController(
    text: widget.user?['profile']?['bio'] ?? '',
  );
  String message = '';
  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        controller: name,
        decoration: InputDecoration(
          labelText: widget.ar ? 'الاسم الظاهر' : 'Display name',
        ),
      ),
      const SizedBox(height: 15),
      TextField(
        controller: bio,
        maxLength: 500,
        decoration: InputDecoration(labelText: widget.ar ? 'نبذة' : 'Bio'),
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.photo_camera),
        label: Text(widget.ar ? 'تغيير الصورة الشخصية' : 'Change avatar'),
        onPressed: () async {
          try {
            final f = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1024,
              imageQuality: 85,
            );
            if (f == null) return;
            await widget.api.upload('profile/', 'avatar', f.path);
            await widget.onSave();
            if (mounted) {
              setState(
                () =>
                    message = widget.ar ? 'تم تحديث الصورة' : 'Avatar updated',
              );
            }
          } catch (e) {
            if (mounted) setState(() => message = e.toString());
          }
        },
      ),
      FilledButton(
        onPressed: () async {
          try {
            await widget.api.request('profile/', 'PATCH', {
              'display_name': name.text,
              'bio': bio.text,
            });
            await widget.onSave();
            if (mounted) {
              setState(() => message = widget.ar ? 'تم الحفظ' : 'Saved');
            }
          } catch (e) {
            if (mounted) setState(() => message = e.toString());
          }
        },
        child: Text(widget.ar ? 'حفظ' : 'Save'),
      ),
      if (message.isNotEmpty) Text(message),
    ],
  );
}

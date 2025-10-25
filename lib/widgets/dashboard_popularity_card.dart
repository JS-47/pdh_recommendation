import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/popularity_service.dart';

class DashboardPopularityCard extends StatefulWidget {
  final PopularityRepository? service;
  final PopularityWindow initialWindow;
  final String? currentUserId;
  final String? currentUserName;

  const DashboardPopularityCard({
    super.key,
    this.service,
    this.initialWindow = PopularityWindow.week,
    this.currentUserId,
    this.currentUserName,
  });

  @override
  State<DashboardPopularityCard> createState() => _DashboardPopularityCardState();
}

class _DashboardPopularityCardState extends State<DashboardPopularityCard> {
  late final PopularityRepository _service;
  late Future<_CardSnapshot> _loader;
  late final String? _currentUserId;
  late final String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PopularityService();
    final user = FirebaseAuth.instance.currentUser;
    _currentUserId = widget.currentUserId ?? user?.uid;
    _currentUserName = widget.currentUserName ?? user?.displayName;
    _loader = _loadCard();
  }

  Future<_CardSnapshot> _loadCard() async {
    try {
      final page = await _service.fetchLeaderboardPage(
        window: widget.initialWindow,
        limit: 3,
        bypassCache: false,
        cursor: null,
        offset: 0,
      );
      return _CardSnapshot.success(page);
    } catch (error) {
      return _CardSnapshot.error(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_CardSnapshot>(
      future: _loader,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return InkWell(
          onTap: state?.page != null
              ? () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _PopularityDrawerSheet(
                      service: _service,
                      initialWindow: widget.initialWindow,
                      seededEntry: state?.page?.myEntry,
                      currentUserId: _currentUserId,
                    ),
                  );
                }
              : null,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Popularity',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(height: 8.0),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(),
                  )
                else if (state?.error != null)
                  Text(
                    state!.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                else
                  _CardContent(
                    page: state!.page!,
                    window: widget.initialWindow,
                    currentUserId: _currentUserId,
                    currentUserName: _currentUserName,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardContent extends StatelessWidget {
  final LeaderboardPage page;
  final PopularityWindow window;
  final String? currentUserId;
  final String? currentUserName;

  const _CardContent({
    required this.page,
    required this.window,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    final me = page.myEntry;
    final likes = me?.user.totalLikes ?? 0;
    final likesText = likes == 0
        ? 'Get your first like ✨'
        : '${formatter.format(likes)} likes';
    final rankText = me?.rank != null ? '#${me!.rank}' : 'Unranked';
    final username = me?.user.username ?? currentUserName ?? (currentUserId != null ? 'You' : 'Guest');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$username is $rankText (${window.label})',
          style: const TextStyle(
            fontSize: 13.0,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          likesText,
          style: const TextStyle(
            fontSize: 13.0,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12.0),
        if (page.entries.isEmpty)
          const Text(
            'No leaderboard data yet. Tap to check back later!',
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top ranked',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8.0),
              ...page.entries.map(
                (entry) => _TopEntryRow(
                  entry: entry,
                  currentUserId: currentUserId,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Tap to open the full leaderboard',
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TopEntryRow extends StatelessWidget {
  final RankedPopularity entry;
  final String? currentUserId;

  const _TopEntryRow({required this.entry, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.compact();
    final isCurrentUser =
        currentUserId != null && entry.user.userId == currentUserId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blueGrey.shade100,
            child: Text(
              entry.rank != null ? '#${entry.rank}' : '-',
              style: const TextStyle(fontSize: 12.0,color: Colors.black87,fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? 'You' : entry.user.username,
                  style: const TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${formatter.format(entry.user.totalLikes)} likes',
                  style: const TextStyle(
                    fontSize: 12.0,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSnapshot {
  final LeaderboardPage? page;
  final String? error;

  const _CardSnapshot._({this.page, this.error});

  factory _CardSnapshot.success(LeaderboardPage page) =>
      _CardSnapshot._(page: page);

  factory _CardSnapshot.error(String message) =>
      _CardSnapshot._(error: message);
}

class _PopularityDrawerSheet extends StatelessWidget {
  final PopularityRepository service;
  final PopularityWindow initialWindow;
  final RankedPopularity? seededEntry;
  final String? currentUserId;

  const _PopularityDrawerSheet({
    required this.service,
    required this.initialWindow,
    required this.seededEntry,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: PopularityDrawer(
            service: service,
            initialWindow: initialWindow,
            seededEntry: seededEntry,
            currentUserId: currentUserId,
          ),
        ),
      ),
    );
  }
}

class PopularityDrawer extends StatefulWidget {
  final PopularityRepository service;
  final PopularityWindow initialWindow;
  final RankedPopularity? seededEntry;
  final String? currentUserId;

  const PopularityDrawer({
    super.key,
    required this.service,
    required this.initialWindow,
    this.seededEntry,
    this.currentUserId,
  });

  @override
  State<PopularityDrawer> createState() => _PopularityDrawerState();
}

class _PopularityDrawerState extends State<PopularityDrawer> {
  static const _pageSize = 20;

  late PopularityWindow _window;
  RankedPopularity? _myEntry;
  List<RankedPopularity> _entries = [];
  PopularityCursor? _cursor;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int? _totalCount;
  int? _lastLikes;
  int? _lastRank;

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _window = widget.initialWindow;
    _myEntry = widget.seededEntry;
    _controller.addListener(_maybeLoadMore);
    _load(reset: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_hasMore || _isLoading) return;
    if (_controller.position.extentAfter < 200) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (reset) {
        _error = null;
        _entries = [];
        _cursor = null;
        _hasMore = true;
        _lastLikes = null;
        _lastRank = null;
      }
    });

    try {
      final page = await widget.service.fetchLeaderboardPage(
        window: _window,
        limit: _pageSize,
        cursor: reset ? null : _cursor,
        offset: reset ? 0 : _entries.length,
        lastLikes: reset ? null : _lastLikes,
        lastRank: reset ? null : _lastRank,
        bypassCache: false,
      );

      setState(() {
        if (reset) {
          _entries = List.of(page.entries);
        } else {
          _entries.addAll(page.entries);
        }
        _cursor = page.cursor;
        _hasMore = page.cursor != null;
        _totalCount = page.totalCount ?? _totalCount;
        _lastLikes = page.lastLikes;
        _lastRank = page.lastRank;
        if (page.myEntry != null) {
          _myEntry = page.myEntry;
        }
        _error = null;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeWindow(PopularityWindow window) {
    if (_window == window) return;
    setState(() {
      _window = window;
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windows = PopularityWindow.values;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Popularity Leaderboard',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: windows
                      .map(
                        (window) => ChoiceChip(
                          label: Text(window.label),
                          selected: _window == window,
                          onSelected: (_) => _changeWindow(window),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? _ErrorState(message: _error!, onRetry: () => _load(reset: true))
                : _entries.isEmpty && _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? const _EmptyState()
                        : _LeaderboardList(
                            controller: _controller,
                            entries: _entries,
                            isLoadingMore: _isLoading && _entries.isNotEmpty,
                            hasMore: _hasMore,
                            myEntry: _myEntry,
                            totalCount: _totalCount,
                            currentUserId: widget.currentUserId,
                          ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final ScrollController controller;
  final List<RankedPopularity> entries;
  final bool isLoadingMore;
  final bool hasMore;
  final RankedPopularity? myEntry;
  final int? totalCount;
  final String? currentUserId;

  const _LeaderboardList({
    required this.controller,
    required this.entries,
    required this.isLoadingMore,
    required this.hasMore,
    required this.myEntry,
    required this.totalCount,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    final hasPinnedRow = myEntry != null &&
        entries.every((entry) => entry.user.userId != myEntry!.user.userId);
    final itemCount = entries.length + 1 + (hasPinnedRow ? 1 : 0);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final isPinnedRow = hasPinnedRow && index == itemCount - 1;
        if (index == entries.length && !isPinnedRow) {
          if (!hasMore && !isLoadingMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                totalCount != null
                    ? 'Showing ${entries.length} of $totalCount users'
                    : 'End of leaderboard',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (isPinnedRow) {
          return Column(
            children: [
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orangeAccent,
                  child: Text(
                    myEntry!.rank != null ? '#${myEntry!.rank}' : '-',
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ),
                title: const Text('My Rank'),
                subtitle: Text(
                  '${formatter.format(myEntry!.user.totalLikes)} likes',
                ),
                trailing: myEntry!.rank == null
                    ? const Text(
                        'Not ranked yet',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      )
                    : null,
              ),
            ],
          );
        }

        final entry = entries[index];
        final isMe =
            currentUserId != null && entry.user.userId == currentUserId;
        return Column(
          children: [
            if (index != 0) const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    isMe ? Colors.orangeAccent : Colors.blueGrey.shade100,
                child: Text(
                  entry.rank != null ? '#${entry.rank}' : '-',
                  style: const TextStyle(fontSize: 12.0,color: Colors.black87,fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(isMe ? 'You' : entry.user.username),
              subtitle: Text('${formatter.format(entry.user.totalLikes)} likes'),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No popularity data found. Be the first to collect some likes!',
        textAlign: TextAlign.center,
      ),
    );
  }
}

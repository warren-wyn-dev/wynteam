from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# ViewProfileScreen: one page-level refresh + suggested-follow sheet.
# ---------------------------------------------------------------------------
view_path = ROOT / "app/lib/features/profile/presentation/view_profile_screen.dart"
view = view_path.read_text(encoding="utf-8")

view = replace_once(
    view,
    "import 'widgets/profile_recommendation_section.dart';\n"
    "import 'widgets/profile_redrops_tab.dart';",
    "import 'widgets/profile_recommendation_section.dart';\n"
    "import 'widgets/profile_redrops_tab.dart';\n"
    "import 'widgets/profile_refresh_coordinator.dart';\n"
    "import 'widgets/suggested_follow_sheet.dart';",
    "profile imports",
)

view = replace_once(
    view,
    "class _ViewProfileScreenState extends State<ViewProfileScreen> {\n"
    "  late Future<_ProfileWithCounts> _loadFuture;",
    "class _ViewProfileScreenState extends State<ViewProfileScreen> {\n"
    "  late Future<_ProfileWithCounts> _loadFuture;\n"
    "  final ProfileRefreshCoordinator _refreshCoordinator =\n"
    "      ProfileRefreshCoordinator();\n"
    "  bool _isProfileRefreshInFlight = false;",
    "profile refresh state",
)

refresh_method = r'''
  /// One pull gesture refreshes Profile as one surface: header, counts,
  /// relationship state and every mounted profile-tab data source. The tab
  /// widgets suppress their own RefreshIndicator while coordinated here, so
  /// the user sees exactly one spinner and one completion point.
  Future<void> _refreshWholeProfile() async {
    if (_isProfileRefreshInFlight) return;
    _isProfileRefreshInFlight = true;

    try {
      // Keep the current Profile visible while refreshing. Swapping the
      // FutureBuilder back to a loading Future would flash the skeleton and
      // make one pull gesture look like two independent refresh operations.
      final freshDataFuture = _load();
      final secondaryRefreshes = <Future<void>>[
        _refreshCoordinator.refreshAll(),
      ];
      if (_isOwnProfile) {
        secondaryRefreshes.add(_loadPendingRequestCount());
      } else {
        secondaryRefreshes.addAll([
          _loadFollowStatus(),
          _loadBlockRelationship(),
          _loadMuteStatus(),
          _loadPendingRequestStatus(),
        ]);
      }

      final freshData = await freshDataFuture;
      await Future.wait(secondaryRefreshes);
      if (!mounted) return;
      setState(() => _loadFuture = Future.value(freshData));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รีเฟรชโปรไฟล์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      _isProfileRefreshInFlight = false;
    }
  }

'''
marker = "  Future<void> _loadFollowStatus() async {"
if view.count(marker) != 1:
    raise SystemExit("refresh method insertion marker not unique")
view = view.replace(marker, refresh_method + marker, 1)

suggested_method = r'''
  Future<void> _openSuggestedFollowers() async {
    await showSuggestedFollowSheet(
      context,
      discoveryRepository: _discoveryRepository,
      followRepository: widget.followRepository,
      followRequestRepository: _followRequestRepository,
      excludeUserId: widget.userId,
      onShowAll: _openSearch,
    );

    // A Follow action in the sheet can change this profile's Following count.
    // Resync via the same whole-page refresh path instead of independently
    // mutating only that number.
    if (mounted) await _refreshWholeProfile();
  }

'''
search_marker = "  void _openSearch() {"
if view.count(search_marker) != 1:
    raise SystemExit("suggested-follow method marker not unique")
view = view.replace(search_marker, suggested_method + search_marker, 1)

view = replace_once(
    view,
    "          WynosProfileIconAction(\n"
    "            icon: Icons.person_add_alt_1_outlined,\n"
    "            tooltip: 'ค้นหาเพื่อน',\n"
    "            onPressed: _openSearch,\n"
    "          ),",
    "          WynosProfileIconAction(\n"
    "            icon: Icons.person_add_alt_1_outlined,\n"
    "            tooltip: 'แนะนำสำหรับคุณ',\n"
    "            onPressed: _openSuggestedFollowers,\n"
    "          ),",
    "suggested-follow profile action",
)

view = replace_once(
    view,
    "            return NestedScrollView(\n"
    "              headerSliverBuilder: (context, innerBoxIsScrolled) => [",
    "            return RefreshIndicator(\n"
    "              onRefresh: _refreshWholeProfile,\n"
    "              notificationPredicate: (notification) =>\n"
    "                  notification.metrics.axis == Axis.vertical,\n"
    "              child: NestedScrollView(\n"
    "                physics: const AlwaysScrollableScrollPhysics(),\n"
    "                headerSliverBuilder: (context, innerBoxIsScrolled) => [",
    "page-level RefreshIndicator",
)

count = view.count("onRefreshHeader: _reload,")
if count != 3:
    raise SystemExit(f"profile tab refresh wiring: expected 3, found {count}")
view = view.replace(
    "onRefreshHeader: _reload,",
    "refreshCoordinator: _refreshCoordinator,",
)

# On 320-430px viewports a fixed one-third tab can be narrower than the icon +
# Thai label. Scale only the tab contents down as needed; the Tab itself and
# touch target keep their full width/height.
for icon, label in [
    ("Icons.image_outlined", "สื่อ"),
    ("Icons.repeat_rounded", "รีโพสต์"),
    ("Icons.favorite_border_rounded", "ถูกใจ"),
]:
    old = f'''                          child: Row(\n                            mainAxisAlignment: MainAxisAlignment.center,\n                            children: [\n                              Icon({icon}, size: 20),\n                              SizedBox(width: 7),\n                              Text('{label}'),\n                            ],\n                          ),'''
    new = f'''                          child: FittedBox(\n                            fit: BoxFit.scaleDown,\n                            child: Row(\n                              mainAxisSize: MainAxisSize.min,\n                              children: [\n                                Icon({icon}, size: 20),\n                                SizedBox(width: 7),\n                                Text('{label}'),\n                              ],\n                            ),\n                          ),'''
    view = replace_once(view, old, new, f"responsive tab {label}")

# Close NestedScrollView, then RefreshIndicator.
tail = "              ),\n            );\n          },\n        ),\n      ),\n    );\n  }\n}"
replacement_tail = "              ),\n              ),\n            );\n          },\n        ),\n      ),\n    );\n  }\n}"
idx = view.rfind(tail)
if idx < 0:
    raise SystemExit("profile RefreshIndicator closing tail not found")
view = view[:idx] + replacement_tail + view[idx + len(tail):]
view_path.write_text(view, encoding="utf-8")


# ---------------------------------------------------------------------------
# Profile tabs: register non-blocking data refresh with the page coordinator.
# Keep their standalone RefreshIndicator behavior when constructed without a
# coordinator so existing isolated uses/tests retain their old contract.
# ---------------------------------------------------------------------------
def patch_tab(relative_path: str, widget_class: str) -> None:
    path = ROOT / relative_path
    text = path.read_text(encoding="utf-8")

    text = replace_once(
        text,
        "import '../../../../core/design/wyn_spacing.dart';\n",
        "import '../../../../core/design/wyn_spacing.dart';\n"
        "import 'profile_refresh_coordinator.dart';\n",
        f"{widget_class} coordinator import",
    )

    text = replace_once(
        text,
        "    required this.emptyText,\n"
        "    this.onRefreshHeader,\n"
        "  });",
        "    required this.emptyText,\n"
        "    this.onRefreshHeader,\n"
        "    this.refreshCoordinator,\n"
        "  });",
        f"{widget_class} constructor",
    )

    text = replace_once(
        text,
        "  final VoidCallback? onRefreshHeader;\n",
        "  final VoidCallback? onRefreshHeader;\n\n"
        "  /// Non-null when ViewProfileScreen owns the one visible pull-to-refresh.\n"
        "  final ProfileRefreshCoordinator? refreshCoordinator;\n",
        f"{widget_class} coordinator field",
    )

    old_init = (
        "  @override\n"
        "  void initState() {\n"
        "    super.initState();\n"
        "    _loadInitial();\n"
        "  }\n"
    )
    new_init = (
        "  @override\n"
        "  void initState() {\n"
        "    super.initState();\n"
        "    widget.refreshCoordinator?.attach(this, _refreshFromPage);\n"
        "    _loadInitial();\n"
        "  }\n\n"
        "  @override\n"
        f"  void didUpdateWidget(covariant {widget_class} oldWidget) {{\n"
        "    super.didUpdateWidget(oldWidget);\n"
        "    if (oldWidget.refreshCoordinator != widget.refreshCoordinator) {\n"
        "      oldWidget.refreshCoordinator?.detach(this);\n"
        "      widget.refreshCoordinator?.attach(this, _refreshFromPage);\n"
        "    }\n"
        "  }\n\n"
        "  @override\n"
        "  void dispose() {\n"
        "    widget.refreshCoordinator?.detach(this);\n"
        "    super.dispose();\n"
        "  }\n\n"
        "  Future<void> _refreshFromPage() => _loadInitial(showLoading: false);\n"
    )
    text = replace_once(text, old_init, new_init, f"{widget_class} lifecycle")

    text = replace_once(
        text,
        "  Future<void> _loadInitial() async {\n"
        "    setState(() {\n"
        "      _isLoadingInitial = true;\n"
        "      _error = null;\n"
        "    });",
        "  Future<void> _loadInitial({bool showLoading = true}) async {\n"
        "    setState(() {\n"
        "      if (showLoading) _isLoadingInitial = true;\n"
        "      _error = null;\n"
        "    });",
        f"{widget_class} non-blocking refresh",
    )

    text = replace_once(
        text,
        "      if (mounted) setState(() => _isLoadingInitial = false);",
        "      if (mounted && showLoading) {\n"
        "        setState(() => _isLoadingInitial = false);\n"
        "      }",
        f"{widget_class} loading completion",
    )

    text = replace_once(
        text,
        "    return RefreshIndicator(\n"
        "      onRefresh: _onPullToRefresh,\n"
        "      child: NotificationListener<ScrollNotification>(",
        "    final content = NotificationListener<ScrollNotification>(",
        f"{widget_class} content wrapper",
    )

    old_suffix = "          ],\n        ),\n      ),\n    );\n  }\n}\n"
    new_suffix = (
        "          ],\n"
        "        ),\n"
        "      );\n"
        "    if (widget.refreshCoordinator != null) return content;\n"
        "    return RefreshIndicator(\n"
        "      onRefresh: _onPullToRefresh,\n"
        "      child: content,\n"
        "    );\n"
        "  }\n"
        "}\n"
    )
    if not text.endswith(old_suffix):
        raise SystemExit(f"{widget_class} final RefreshIndicator suffix not found")
    text = text[: -len(old_suffix)] + new_suffix
    path.write_text(text, encoding="utf-8")


patch_tab(
    "app/lib/features/profile/presentation/widgets/profile_drop_grid_tab.dart",
    "ProfileDropGridTab",
)
patch_tab(
    "app/lib/features/profile/presentation/widgets/profile_redrops_tab.dart",
    "ProfileRedropsTab",
)
patch_tab(
    "app/lib/features/profile/presentation/widgets/profile_likes_tab.dart",
    "ProfileLikesTab",
)

print("Applied profile polish + unified refresh patch")

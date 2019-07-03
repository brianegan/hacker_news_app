import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:hnpwa_client/hnpwa_client.dart';
import 'package:isolate/isolate.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hacker News App',
      theme: ThemeData(
        backgroundColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Signika',
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.dark,
      ),
      home: TopStoriesPage(
        repository: HackerNewsRepository(
          ItemCache(),
          FeedCache(),
          HnpwaClient(),
          LoadBalancer.create(1, IsolateRunner.spawn),
        ),
      ),
    );
  }
}

class TopStoriesPage extends StatefulWidget {
  final HackerNewsRepository repository;

  const TopStoriesPage({Key key, @required this.repository}) : super(key: key);

  @override
  _TopStoriesPageState createState() => _TopStoriesPageState();
}

class FetchStoryParams {
  final HnpwaClient client;
  final int itemId;

  FetchStoryParams(this.client, this.itemId);
}

class FetchTopStoriesParams {
  final HnpwaClient client;
  final int page;

  FetchTopStoriesParams(this.client, this.page);
}

class _TopStoriesPageState extends State<TopStoriesPage> {
  Future<Feed> _topStories;

  @override
  void initState() {
    _topStories = widget.repository.topStories();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Feed>(
        future: _topStories,
        builder: (context, snapshot) {
          return AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            child: _buildChild(snapshot),
          );
        },
      ),
    );
  }

  Widget _buildChild(AsyncSnapshot<Feed> snapshot) {
    if (snapshot.hasData) {
      return FeedView(
        items: snapshot.data.items,
        repository: widget.repository,
        onRefresh: () async {
          setState(() {
            _topStories = widget.repository.topStories(refresh: true);
          });

          await _topStories;
        },
      );
    } else if (snapshot.hasError) {
      return ErrorView(error: snapshot.error);
    } else {
      return LoadingView();
    }
  }
}

class FeedView extends StatelessWidget {
  final List<FeedItem> items;
  final RefreshCallback onRefresh;
  final HackerNewsRepository repository;

  const FeedView({
    Key key,
    @required this.items,
    @required this.onRefresh,
    @required this.repository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            floating: true,
            title: Row(children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 24),
                child: Icon(Icons.trending_up),
              ),
              Text("Trending"),
            ]),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                return FeedItemView(
                  feedItem: items[i],
                  repository: repository,
                );
              },
              childCount: items.length,
            ),
          )
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(),
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;

  const ErrorView({Key key, @required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.error),
          Padding(
            padding: EdgeInsets.all(24),
            child: Text('Oh no, an error occurred!'),
          ),
          Padding(
            padding: EdgeInsets.all(24),
            child: Text('$error'),
          ),
        ],
      ),
    );
  }
}

class FeedItemView extends StatelessWidget {
  final FeedItem feedItem;
  final HackerNewsRepository repository;
  final Color color;

  const FeedItemView({
    Key key,
    @required this.feedItem,
    @required this.repository,
    this.color = Colors.transparent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () async {
            if (await canLaunch(feedItem.url)) {
              await launch(feedItem.url);
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: 4,
            ),
            child: StoryTitle(
              title: feedItem.title,
              id: feedItem.id,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 24,
            bottom: 16,
          ),
          child: StatsView(
            score: feedItem.points,
            commentsCount: '${feedItem.commentsCount}+',
            onCommentsPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return ItemScreen(
                      title: feedItem.title,
                      repository: repository,
                      id: feedItem.id,
                    );
                  },
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

class StatsView extends StatelessWidget {
  final int score;
  final String commentsCount;
  final Function() onCommentsPressed;

  const StatsView({
    Key key,
    @required this.score,
    @required this.commentsCount,
    this.onCommentsPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var comments = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.chat_bubble_outline, size: 14),
          ),
          Text(commentsCount),
        ],
      ),
    );

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(Icons.keyboard_arrow_up),
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.only(right: 0),
          child: Text('$score'),
        ),
        onCommentsPressed != null
            ? InkWell(onTap: onCommentsPressed, child: comments)
            : comments,
      ],
    );
  }
}

class StoryTitle extends StatelessWidget {
  final String title;
  final int id;
  final double fontSize;
  final double lineHeight;

  const StoryTitle({
    Key key,
    @required this.title,
    @required this.id,
    this.fontSize = 24,
    this.lineHeight = 1.3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        decoration: TextDecoration.underline,
        decorationColor: Colors.white70,
      ),
    );
  }
}

class ItemScreen extends StatefulWidget {
  final String title;
  final int id;
  final HackerNewsRepository repository;

  const ItemScreen({
    Key key,
    @required this.id,
    @required this.repository,
    @required this.title,
  }) : super(key: key);

  @override
  _ItemScreenState createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  Future<Item> _itemFuture;

  @override
  void initState() {
    _itemFuture = widget.repository.story(widget.id);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Item>(
        future: _itemFuture,
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24.0,
                      right: 24.0,
                      top: 16.0,
                      bottom: 8.0,
                    ),
                    child: InkWell(
                      onTap: () async {
                        if (await canLaunch(snapshot.data.url)) {
                          await launch(snapshot.data.url);
                        }
                      },
                      child: StoryTitle(
                        title: widget.title,
                        id: widget.id,
                        fontSize: 36.0,
                        lineHeight: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ]..addAll(_addItems(context, snapshot)),
          );
        },
      ),
    );
  }

  List<CommentListItem> _buildComments(Item comment, int indentationLevel) {
    final items = [CommentListItem(comment, indentationLevel)];

    if (comment.comments?.isEmpty ?? true) {
      return items;
    } else {
      return items
        ..addAll(
            comment.comments.fold<List<CommentListItem>>([], (list, comment) {
          return list..addAll(_buildComments(comment, indentationLevel + 1));
        }));
    }
  }

  Iterable<Widget> _addItems(
    BuildContext context,
    AsyncSnapshot<Item> snapshot,
  ) {
    if (snapshot.hasData) {
      final items = snapshot.data.comments.fold<List<ItemScreenListItem>>(
        [StatsListItem(snapshot.data.points, snapshot.data.commentsCount)],
        (list, comment) {
          return list..addAll(_buildComments(comment, 0));
        },
      );

      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              if (item is StatsListItem) {
                return Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 24,
                    bottom: 20,
                  ),
                  child: StatsView(
                    score: item.score,
                    commentsCount: '${item.numComments}',
                  ),
                );
              } else if (item is CommentListItem) {
                return new CommentView(
                  item: item,
                );
              }
            },
            childCount: items.length,
          ),
        )
      ];
    } else if (snapshot.hasError) {
      return [
        SliverFillRemaining(
          child: ErrorView(error: snapshot.error),
        )
      ];
    }

    return [
      SliverFillRemaining(
        child: LoadingView(),
      )
    ];
  }
}

class CommentView extends StatelessWidget {
  const CommentView({
    Key key,
    @required this.item,
  }) : super(key: key);

  final CommentListItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: item.indentationLevel == 0
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey, width: 1)))
          : null,
      margin: EdgeInsets.only(
        left: 24 + item.indentationLevel * 16.0,
        right: 24,
      ),
      padding: EdgeInsets.only(
        bottom: 16,
        top: item.indentationLevel == 0 ? 16 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.comment.user ?? '[deleted]',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'CreteRound',
              fontSize: 18,
            ),
          ),
          item.comment.content != null
              ? Html(
                  onLinkTap: (link) async {
                    if (await canLaunch(link)) {
                      launch(link);
                    }
                  },
                  blockSpacing: 8,
                  data: item.comment.content,
                  defaultTextStyle: Theme.of(context)
                      .textTheme
                      .body1
                      .copyWith(fontFamily: 'CreteRound', fontSize: 15),
                )
              : Text(
                  '[deleted]',
                  style: TextStyle(
                    fontFamily: 'CreteRound',
                    fontSize: 15,
                  ),
                ),
        ],
      ),
    );
  }
}

abstract class ItemScreenListItem {}

class StatsListItem implements ItemScreenListItem {
  final int score;
  final int numComments;

  StatsListItem(this.score, this.numComments);
}

class CommentListItem implements ItemScreenListItem {
  final Item comment;
  final int indentationLevel;

  CommentListItem(this.comment, this.indentationLevel);
}

class HackerNewsRepository {
  final ItemCache storyCache;
  final FeedCache trendingCache;
  final HnpwaClient client;
  final Future<LoadBalancer> loadBalancer;

  HackerNewsRepository(
    this.storyCache,
    this.trendingCache,
    this.client,
    this.loadBalancer,
  );

  Future<Feed> topStories({int page = 1, bool refresh = false}) async {
    if (!refresh &&
        trendingCache.isNotEmpty &&
        trendingCache.feed.currentPage == page) {
      return trendingCache.feed;
    }

    final results = await (await loadBalancer).run(
      _fetchTopStoriesInBackground,
      FetchTopStoriesParams(client, page),
    );

    trendingCache.feed = Feed(
      items: (trendingCache.feed?.items ?? []) + results.items,
      currentPage: results.currentPage,
      nextPage: results.nextPage,
    );

    return trendingCache.feed;
  }

  Future<Item> story(int id) async {
    if (storyCache.contains(id)) return storyCache.item(id);

    final results = await (await loadBalancer)
        .run(_fetchStoryInBackground, FetchStoryParams(client, id));

    storyCache.add(results);

    return results;
  }

  static Future<Feed> _fetchTopStoriesInBackground(
    FetchTopStoriesParams params,
  ) {
    return params.client.news(page: params.page);
  }

  static Future<Item> _fetchStoryInBackground(
    FetchStoryParams params,
  ) {
    return params.client.item(params.itemId);
  }
}

class FeedCache {
  Feed feed;

  bool get isEmpty => feed == null;

  bool get isNotEmpty => feed != null;

  void clear() => feed = null;
}

class ItemCache {
  final Map<int, Item> _items = {};

  bool contains(int itemId) => _items.containsKey(itemId);

  Item item(int itemId) => _items[itemId];

  void add(Item item) => _items[item.id] = item;

  void clear() {
    _items.clear();
  }
}

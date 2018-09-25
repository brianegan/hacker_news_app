import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:hacker_news_client/hacker_news_client.dart' as hn;
import 'package:http/http.dart';
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
          StoriesCache(),
          TrendingCache(),
          hn.HackerNewsClient(IOClient()),
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
  final hn.HackerNewsClient client;
  final int storyId;

  FetchStoryParams(this.client, this.storyId);
}

class _TopStoriesPageState extends State<TopStoriesPage> {
  Future<List<hn.Summary>> _topStories;

  @override
  void initState() {
    _topStories = widget.repository.topStories();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<hn.Summary>>(
        future: _topStories,
        builder: (context, snapshot) {
          final items = snapshot.data == null ? [] : snapshot.data;

          return AnimatedStack(
            currentIndex: snapshot.hasData ? 2 : snapshot.hasError ? 1 : 0,
            children: [
              LoadingView(),
              ErrorView(error: snapshot.error),
              RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _topStories = widget.repository.topStories();
                  });

                  await _topStories;
                },
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.black,
                      elevation: 0.0,
                      floating: true,
                      title: Row(children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 8.0, right: 24.0),
                          child: Icon(Icons.trending_up),
                        ),
                        Text("Trending"),
                      ]),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final summary = items[i];

                          return StoryItem(
                            summary: summary,
                            repository: widget.repository,
                          );
                        },
                        childCount: items.length,
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
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
            padding: EdgeInsets.all(24.0),
            child: Text('Oh no, an error occurred!'),
          ),
          Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('$error'),
          ),
        ],
      ),
    );
  }
}

class StoryItem extends StatelessWidget {
  final hn.Summary summary;
  final HackerNewsRepository repository;
  final Color color;

  const StoryItem({
    Key key,
    @required this.summary,
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
            if (await canLaunch(summary.url)) {
              await launch(summary.url);
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              bottom: 4.0,
            ),
            child: StoryTitle(
              title: summary.title,
              id: summary.id,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 20.0,
            right: 24.0,
            bottom: 16.0,
          ),
          child: StatsView(
            score: summary.score,
            commentsCount: '${summary.kids.length}+',
            onCommentsPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return StoryPage(
                      title: summary.title,
                      repository: repository,
                      id: summary.id,
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
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(Icons.chat_bubble_outline, size: 14.0),
          ),
          Text(commentsCount),
        ],
      ),
    );

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: Icon(Icons.keyboard_arrow_up),
        ),
        Container(
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.only(right: 0.0),
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
    this.fontSize = 24.0,
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

class StoryPage extends StatefulWidget {
  final String title;
  final int id;
  final HackerNewsRepository repository;

  const StoryPage({
    Key key,
    @required this.id,
    @required this.repository,
    @required this.title,
  }) : super(key: key);

  @override
  _StoryPageState createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  Future<hn.Story> _storyFuture;

  @override
  void initState() {
    _storyFuture = widget.repository.story(widget.id);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<hn.Story>(
        future: _storyFuture,
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

  List<CommentItem> _buildComments(hn.Comment comment, int indentationLevel) {
    final items = [CommentItem(comment, indentationLevel)];

    if (comment.comments?.isEmpty ?? true) {
      return items;
    } else {
      return items
        ..addAll(comment.comments.fold<List<CommentItem>>([], (list, comment) {
          return list..addAll(_buildComments(comment, indentationLevel + 1));
        }));
    }
  }

  Iterable<Widget> _addItems(
    BuildContext context,
    AsyncSnapshot<hn.Story> snapshot,
  ) {
    if (snapshot.hasData) {
      final items = snapshot.data.comments.fold<List<StoryPageItem>>(
        [StatsItem(snapshot.data.score, snapshot.data.numComments)],
        (list, comment) {
          return list..addAll(_buildComments(comment, 0));
        },
      );

      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              if (item is StatsItem) {
                return Padding(
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    right: 24.0,
                  ),
                  child: StatsView(
                    score: item.score,
                    commentsCount: '${item.numComments}',
                  ),
                );
              } else if (item is CommentItem) {
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

  final CommentItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: item.indentationLevel * 16.0,
      ),
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        bottom: 24.0,
        top: item.indentationLevel == 0 ? 16.0 : 0.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              item.comment.by ?? '[deleted]',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'CreteRound',
                fontSize: 18.0,
              ),
            ),
          ),
          item.comment.text != null
              ? Html(
                  data: item.comment.text,
                  defaultTextStyle: Theme.of(context)
                      .textTheme
                      .body1
                      .copyWith(fontFamily: 'CreteRound', fontSize: 15.0),
                )
              : Text(
                  '[deleted]',
                  style: TextStyle(
                    fontFamily: 'CreteRound',
                    fontSize: 15.0,
                  ),
                ),
        ],
      ),
    );
  }
}

class StoryIcon extends StatelessWidget {
  final hn.StoryType type;

  const StoryIcon({Key key, @required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case hn.StoryType.poll:
        return Icon(Icons.poll);
      case hn.StoryType.comment:
        return Icon(Icons.comment);
      case hn.StoryType.job:
        return Icon(Icons.work);
      case hn.StoryType.story:
      default:
        return Icon(Icons.format_align_left);
    }
  }
}

abstract class StoryPageItem {}

class StatsItem implements StoryPageItem {
  final int score;
  final int numComments;

  StatsItem(this.score, this.numComments);
}

class CommentItem implements StoryPageItem {
  final hn.Comment comment;
  final int indentationLevel;

  CommentItem(this.comment, this.indentationLevel);
}

class AnimatedStack extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const AnimatedStack({
    Key key,
    @required this.children,
    @required this.currentIndex,
  }) : super(key: key);

  @override
  _AnimatedStackState createState() => _AnimatedStackState();
}

class _AnimatedStackState extends State<AnimatedStack>
    with TickerProviderStateMixin {
  List<AnimationController> controllers;

  @override
  void initState() {
    controllers = List.generate(widget.children.length, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 500),
        value: widget.currentIndex == i ? 1.0 : 0.0,
      );
    });
    super.initState();
  }

  @override
  void didUpdateWidget(AnimatedStack oldWidget) {
    if (oldWidget.currentIndex != widget.currentIndex) {
      controllers[oldWidget.currentIndex].reverse();
      controllers[widget.currentIndex].forward();
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    controllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (i) {
        return FadeTransition(
          opacity: controllers[i],
          child: widget.children[i],
        );
      }),
    );
  }
}

class HackerNewsRepository {
  final StoriesCache storyCache;
  final TrendingCache trendingCache;
  final hn.HackerNewsClient client;
  final Future<LoadBalancer> loadBalancer;

  HackerNewsRepository(
    this.storyCache,
    this.trendingCache,
    this.client,
    this.loadBalancer,
  );

  Future<List<hn.Summary>> topStories() async {
    if (trendingCache.isNotEmpty) return trendingCache.summaries;

    final results =
        await (await loadBalancer).run(_fetchTopStoriesInBackground, client);

    trendingCache.summaries = results;

    return results;
  }

  Future<hn.Story> story(int id) async {
    if (storyCache.contains(id)) return storyCache.story(id);

    final results = await (await loadBalancer)
        .run(_fetchStoryInBackground, FetchStoryParams(client, id));

    storyCache.add(results);

    return results;
  }

  static Future<List<hn.Summary>> _fetchTopStoriesInBackground(
    hn.HackerNewsClient client,
  ) {
    return client.topStories();
  }

  static Future<hn.Story> _fetchStoryInBackground(
    FetchStoryParams params,
  ) {
    return params.client.story(params.storyId);
  }
}

class TrendingCache {
  List<hn.Summary> summaries;

  bool get isEmpty => summaries == null;

  bool get isNotEmpty => summaries != null;

  void clear() => summaries = null;
}

class StoriesCache {
  final Map<int, hn.Story> _stories = {};

  bool contains(int storyId) => _stories.containsKey(storyId);

  hn.Story story(int storyId) => _stories[storyId];

  void add(hn.Story story) => _stories[story.id] = story;

  void clear() {
    _stories.clear();
  }
}

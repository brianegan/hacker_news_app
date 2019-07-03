import 'dart:async';

import 'package:hnpwa_client/hnpwa_client.dart' as hn;

typedef FetchFeedUseCase = Future<hn.Feed> Function(int page);

abstract class FeedPresenter {
  final FetchFeedUseCase fetchFeed;

  FeedPresenter(this.fetchFeed);

  void fetchFirstPage();

  void fetchNextPage();

  Future<void> refresh();

  Stream<FeedState> feed;
}

abstract class FeedState {}

class FeedLoading extends FeedState {}

class FeedEmpty extends FeedState {}

class FeedError extends FeedState {
  final String message;

  FeedError(this.message);
}

class FeedPopulated extends FeedState {
  final List<FeedItem> items;
  final int currentPage;
  final int nextPage;

  bool get hasNextPage => nextPage != null;

  FeedPopulated(this.items, this.currentPage, this.nextPage);
}

abstract class FeedItem {}

class Item extends FeedItem {
  final String url;
  final String title;
  final String id;
  final int commentCount;
  final int points;

  Item({this.url, this.title, this.id, this.commentCount, this.points});
}

class LoadingNextPageError extends FeedItem {}

class LoadingNextPage extends FeedItem {}

abstract class ItemBloc {
  final Item initialItem;

  ItemBloc({this.initialItem});

  Stream<ItemState> item;
}

abstract class ItemState {}

class ItemLoading extends ItemState {}

class ItemLoadingError extends ItemState {}

class ItemPopulated extends ItemState {}

abstract class ItemItem {}

class TitleItem implements ItemItem {
  final String url;
  final String title;
  final String id;

  TitleItem(this.url, this.title, this.id);
}

class StatsItem implements ItemItem {
  final int score;
  final int numComments;

  StatsItem(this.score, this.numComments);
}

class CommentItem implements ItemItem {
  final String author;
  final String body;
  final int indentationLevel;

  CommentItem(this.author, this.body, this.indentationLevel);
}
